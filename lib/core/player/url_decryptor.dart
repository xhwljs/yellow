import 'dart:async';
import 'dart:convert';

import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/parser/video_detail_parser.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/core/utils/user_agent_utils.dart';
import 'package:videohub/data/models/video_detail.dart';

/// 播放地址解密模块
///
/// 严格遵循需求：
/// - 模拟移动端点击手势（生成随机屏幕坐标）
/// - 内置 6 秒倒计时等待逻辑
/// - 发送 POST 请求到 /static/count.php 接口
/// - Base64 解码获取真实视频播放地址
/// - 地址时效性校验、失效自动重新拉取
class UrlDecryptor {
  final ApiService _apiService;

  UrlDecryptor(this._apiService);

  /// 获取真实播放地址（完整流程）
  ///
  /// 1. 拉取详情页 HTML，提取 AK token
  /// 2. 6 秒倒计时（模拟点击等待）
  /// 3. POST /static/count.php 获取加密地址
  /// 4. Base64 解码
  /// 5. 地址时效性校验
  ///
  /// 返回 (playUrl, videoDetail)
  Future<({String playUrl, VideoDetail detail})> decryptPlayUrl(
    String videoId, {
    void Function(int secondsLeft)? onCountdown,
    VideoDetail? existingDetail,
  }) async {
    appLogger.i('开始解密播放地址: videoId=$videoId');

    // 1. 拉取详情页（若未提供已有详情）
    VideoDetail detail;
    if (existingDetail != null && existingDetail.token != null) {
      detail = existingDetail;
    } else {
      detail = await _fetchDetailWithToken(videoId);
    }

    if (detail.token == null || detail.token!.isEmpty) {
      throw const DecryptException('未找到 AK Token，无法解密');
    }

    // 2. 6 秒倒计时（模拟移动端点击等待）
    await _runCountdown(onCountdown: onCountdown);

    // 3. 构造 POST 参数
    final params = _buildParams(
      videoId: videoId,
      token: detail.token!,
      sid: detail.sid ?? '1',
      nid: detail.nid ?? '1',
    );

    // 4. 发送 POST 请求
    final response = await _apiService.postDecryptPlayUrl(params);

    // 5. 解析响应
    final ok = response['ok'];
    final u = response['u'];

    if (ok != true || u is! String || u.isEmpty) {
      throw DecryptException('接口返回异常: $response');
    }

    // 6. Base64 解码
    final playUrl = _decodeBase64Url(u);
    if (playUrl.isEmpty || !playUrl.startsWith('http')) {
      throw DecryptException('解码后地址无效: $playUrl');
    }

    // 7. 时效性校验（URL 中包含 expiry 时间戳的情况）
    _validateUrlExpiry(playUrl);

    appLogger.i('解密成功: $playUrl');
    return (playUrl: playUrl, detail: detail);
  }

  /// 拉取详情页 HTML 并提取 AK Token
  Future<VideoDetail> _fetchDetailWithToken(String videoId) async {
    final html = await _apiService.fetchVideoDetailHtml(videoId);
    return VideoDetailParser.parse(html, videoId);
  }

  /// 6 秒倒计时
  Future<void> _runCountdown({
    void Function(int secondsLeft)? onCountdown,
  }) async {
    for (var i = AppConstants.decryptCountdown.inSeconds; i > 0; i--) {
      appLogger.d('解密倒计时: ${i}s');
      onCountdown?.call(i);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// 构造 POST 请求参数
  ///
  /// id, sid, nid, tk, g, x, y, dt, sw, sh, tz, t
  Map<String, dynamic> _buildParams({
    required String videoId,
    required String token,
    required String sid,
    required String nid,
  }) {
    return {
      'id': videoId,
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
  Future<String> refreshPlayUrl(
    String videoId, {
    void Function(int secondsLeft)? onCountdown,
  }) async {
    var attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final result = await decryptPlayUrl(
          videoId,
          onCountdown: onCountdown,
        );
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
