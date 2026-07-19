import 'dart:async';
import 'dart:convert';

import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/core/network/api_server_switcher.dart';
import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/parser/video_detail_parser.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/core/utils/user_agent_utils.dart';
import 'package:videohub/data/models/video_detail.dart';

/// 播放地址解密模块
///
/// 实测站点 /v5/{aid}-{sid}-{nid}.html 详情页结构（2026-07-19 验证）：
///
/// ```html
/// <script type="text/javascript">
///   (function(){
///     var AID='230796', ASID='1', ANID='1',
///         AK='b5f28b46e459fccbdfbdabc765fc8644af2bd8cd7268ecf9992bf046b0ecbf64';
///     // ...
///     var x=new XMLHttpRequest();
///     x.open('POST','/static/count.php',true);
///     x.setRequestHeader('X-Requested-With','XMLHttpRequest');
///     x.send(xhrBody({id:AID,sid:ASID,nid:ANID,tk:AK,g:1,x,y,dt,sw,sh,tz,t}));
///   })();
/// </script>
/// ```
///
/// 站点原本有 6 秒倒计时锁定按钮，**实测跳过倒计时直接 POST 也能成功**
/// （服务端不校验时间差），因此本模块移除倒计时逻辑，直接请求。
class UrlDecryptor {
  final ApiService _apiService;

  UrlDecryptor(this._apiService);

  /// 获取真实播放地址（完整流程）
  ///
  /// 1. 拉取详情页 HTML，提取 AK token + AID/ASID/ANID
  /// 2. POST /static/count.php 获取加密地址
  /// 3. Base64 解码
  /// 4. 地址时效性校验
  ///
  /// **自动 fallback**：若当前 baseUrl 提取 AK Token 失败（用户持久化了
  /// 未列入 [ApiServerSwitcher._deadMirrors] 的失效镜像），自动切换到
  /// [AppConstants.defaultBaseUrl] 并持久化，然后重试一次。这是用户报告
  /// "未找到 AK Token，无法解密"的最后兜底。
  ///
  /// 返回 (playUrl, videoDetail)
  Future<({String playUrl, VideoDetail detail})> decryptPlayUrl(
    String videoId, {
    VideoDetail? existingDetail,
  }) async {
    appLogger.i('开始解密播放地址: videoId=$videoId');

    try {
      return await _decryptPlayUrlInternal(
        videoId,
        existingDetail: existingDetail,
      );
    } on DecryptException catch (e) {
      // 仅在 "未找到 AK Token" 且当前 baseUrl 非默认时 fallback
      final shouldFallback = e.message.contains('未找到 AK Token') &&
          AppConstants.baseUrl != AppConstants.defaultBaseUrl;

      if (!shouldFallback) rethrow;

      appLogger.w(
        '当前 baseUrl=${AppConstants.baseUrl} 提取 AK Token 失败，'
        '自动 fallback 到 defaultBaseUrl=${AppConstants.defaultBaseUrl} 重试',
      );

      // 切换到 defaultBaseUrl（含 Dio 重建 + SharedPreferences 持久化）
      await ApiServerSwitcher.switchTo(AppConstants.defaultBaseUrl);

      // 强制重新拉取详情页（existingDetail 可能是用旧 baseUrl 拉取的）
      return await _decryptPlayUrlInternal(videoId, existingDetail: null);
    }
  }

  /// 内部解密实现（不含 fallback 逻辑）
  Future<({String playUrl, VideoDetail detail})> _decryptPlayUrlInternal(
    String videoId, {
    VideoDetail? existingDetail,
  }) async {
    // 1. 拉取详情页（若未提供已有详情）
    VideoDetail detail;
    if (existingDetail != null &&
        existingDetail.token != null &&
        existingDetail.token!.isNotEmpty) {
      detail = existingDetail;
    } else {
      detail = await _fetchDetailWithToken(videoId);
    }

    if (detail.token == null || detail.token!.isEmpty) {
      throw const DecryptException('未找到 AK Token，无法解密');
    }

    // 2. 构造 POST 参数
    //
    // id 字段用 detail.aid（从详情页 script 中提取的 AID 值，如 "230796"），
    // 不是 videoId（复合 ID "230796-1-1"）。
    final params = _buildParams(
      id: detail.aid ??
          (videoId.contains('-') ? videoId.split('-').first : videoId),
      token: detail.token!,
      sid: detail.sid ?? '1',
      nid: detail.nid ?? '1',
    );

    // 3. 发送 POST 请求
    //
    // 传递 videoId 用于构造详情页 Referer（POST 接口要求 Referer 指向
    // 具体详情页，不能是首页）。
    final response = await _apiService.postDecryptPlayUrl(
      params,
      refererVideoId: videoId,
    );

    // 4. 解析响应
    final ok = response['ok'];
    final u = response['u'];

    if (ok != true || u is! String || u.isEmpty) {
      throw DecryptException('接口返回异常: $response');
    }

    // 5. Base64 解码
    final playUrl = _decodeBase64Url(u);
    if (playUrl.isEmpty || !playUrl.startsWith('http')) {
      throw DecryptException('解码后地址无效: $playUrl');
    }

    // 6. 时效性校验（URL 中包含 expiry 时间戳的情况）
    _validateUrlExpiry(playUrl);

    appLogger.i('解密成功: $playUrl');
    return (playUrl: playUrl, detail: detail);
  }

  /// 拉取详情页 HTML 并提取 AK Token
  Future<VideoDetail> _fetchDetailWithToken(String videoId) async {
    final html = await _apiService.fetchVideoDetailHtml(videoId);
    return VideoDetailParser.parse(html, videoId);
  }

  /// 构造 POST 请求参数
  ///
  /// 与站点 `<script>` 中 xhrBody({id:AID, sid:ASID, nid:ANID, tk:AK,
  /// g:1, x, y, dt, sw, sh, tz, t}) 逐字段对应。
  ///
  /// 注意：[id] 是从详情页 script 提取的 AID（如 "230796"），
  /// 不是列表页 href 中的复合 `aid-sid-nid`。
  Map<String, dynamic> _buildParams({
    required String id,
    required String token,
    required String sid,
    required String nid,
  }) {
    return {
      'id': id,
      'sid': sid,
      'nid': nid,
      'tk': token,
      'g': '1',
      'x': UserAgentUtils.randomX(),
      'y': UserAgentUtils.randomY(),
      'dt': '1',
      'sw': UserAgentUtils.screenWidth,
      'sh': UserAgentUtils.screenHeight,
      'tz': UserAgentUtils.timezone,
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  /// Base64 解码（兼容 URL-safe + 标准 base64）
  ///
  /// 等价于 Dart: String.fromCharCodes(base64Decode(u))
  String _decodeBase64Url(String encoded) {
    try {
      // URL-safe base64 → standard
      final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');

      // 补齐 padding
      final padding = normalized.length % 4;
      final padded =
          padding == 0 ? normalized : normalized + ('=' * (4 - padding));

      final bytes = base64Decode(padded);
      return utf8.decode(bytes);
    } catch (e) {
      appLogger.e('Base64 解码失败: $e');
      throw const DecryptException('Base64 解码失败');
    }
  }

  /// 时效性校验
  ///
  /// 部分源站点会在 URL 中附加 expiry 时间戳参数（如 ?expires=1700000000）
  /// 若已过期则抛出 UrlExpiredException。
  void _validateUrlExpiry(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final expiryStr =
        uri.queryParameters['expires'] ?? uri.queryParameters['expiry'];
    if (expiryStr == null) return;

    final expiry = int.tryParse(expiryStr);
    if (expiry == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiry < now) {
      throw const UrlExpiredException();
    }
  }

  /// 失效自动重新拉取（带最大重试次数）
  ///
  /// 适用：播放器加载时检测到地址失效。
  Future<String> refreshPlayUrl(String videoId) async {
    var attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final result = await decryptPlayUrl(videoId);
        return result.playUrl;
      } on UrlExpiredException {
        attempts++;
        appLogger.w('播放地址已过期，第 $attempts 次重新拉取');
        await Future.delayed(const Duration(seconds: 2));
      } on DecryptException catch (e) {
        attempts++;
        appLogger.w('解密失败，第 $attempts 次重试: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw const DecryptException('多次重试后仍无法获取播放地址');
  }
}
