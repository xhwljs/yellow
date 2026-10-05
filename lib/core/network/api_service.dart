import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:yellow_depot/core/constants/api_endpoints.dart';
import 'package:yellow_depot/core/network/dio_client.dart';

/// API 服务 — 提供所有 HTTP 接口调用
///
/// 业务层调用 Repository，Repository 调用 ApiService。
///
/// 重要：不缓存 Dio 引用！每次请求动态从 [DioClient.instance] 取最新实例，
/// 这样切换 baseUrl 后（[DioClient.rebuildWithBaseUrl]）能立即生效，
/// 不会因持有已关闭的旧 Dio 而抛
/// "Dio can't establish a new connection after it was closed"。
class ApiService {
  /// 仅用于测试注入 mock Dio；生产环境保持 null，每次动态读取最新 Dio。
  final Dio? _dioOverride;

  ApiService([Dio? dio]) : _dioOverride = dio;

  /// 动态读取当前 DioClient 中的 Dio 实例（baseUrl 切换后会自动跟随）
  Dio get _dio => _dioOverride ?? DioClient.instance;

  /// 获取首页 HTML（用于解析导航菜单获取所有分类）
  Future<String> fetchHomeHtml() async {
    final response = await _dio.get<String>(ApiEndpoints.home);
    return response.data ?? '';
  }

  /// 获取分类视频列表 HTML
  Future<String> fetchCategoryVideosHtml(int categoryId, [int? page]) async {
    final url = ApiEndpoints.categoryVideos(categoryId, page);
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }

  /// 获取视频详情 HTML
  Future<String> fetchVideoDetailHtml(String videoId) async {
    final url = ApiEndpoints.videoDetail(videoId);
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }

  /// 搜索视频 — 返回搜索结果页 HTML
  ///
  /// HTML 结构与分类页一致（含 .stui-vodlist__box，混杂广告），
  /// 由 VideoListParser 解析（categoryId = 0 表示搜索结果）。
  Future<String> searchVideosHtml(String keyword, [int? page]) async {
    final url = ApiEndpoints.search(keyword, page);
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }

  /// 获取专题页 HTML（用于解析 header 区的热门搜索词条）
  Future<String> fetchTopicHtml() async {
    final response = await _dio.get<String>(ApiEndpoints.topic);
    return response.data ?? '';
  }

  /// 搜索联想（macCMS suggest JSON 接口）
  ///
  /// 返回原始 JSON Map：`{code, list: [{id, name, en, pic}], ...}`。
  /// 由 [SearchSuggestService] 转换为 [SearchSuggestion] 列表。
  Future<Map<String, dynamic>> fetchSearchSuggest(String keyword) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.searchSuggest(keyword),
      options: Options(responseType: ResponseType.json),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // 解码失败返回空
      }
    }
    return <String, dynamic>{};
  }

  /// POST 获取播放地址（解密接口）
  ///
  /// 参数: id, sid, nid, tk, g, x, y, dt, sw, sh, tz, t
  /// 返回: JSON {ok: boolean, u: string}
  ///
  /// Header 规则（实测）：
  /// - GET 页面：`X-Requested-With: com.mmbox.xbrowser`（反爬识别）
  /// - POST /static/count.php：`X-Requested-With: XMLHttpRequest`
  ///   否则返回 `{"ok":false,"err":"xhr"}`
  /// - POST Referer 必须指向详情页 `/v5/{aid}-{sid}-{nid}.html`，
  ///   否则可能被识别为非法来源。
  ///
  /// 由 [UserAgentInterceptor] 拦截器统一注入 `X-Requested-With: XMLHttpRequest`，
  /// 此处仅补充 Content-Type 和 Referer（基于 params 中的 id/sid/nid 构造）。
  Future<Map<String, dynamic>> postDecryptPlayUrl(
    Map<String, dynamic> params, {
    String? refererVideoId,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    // 构造详情页 Referer
    if (refererVideoId != null && refererVideoId.isNotEmpty) {
      headers['Referer'] = ApiEndpoints.videoDetail(refererVideoId);
    }

    final response = await _dio.post<dynamic>(
      ApiEndpoints.playUrlDecrypt,
      data: params,
      options: Options(
        responseType: ResponseType.json,
        headers: headers,
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // 解码失败返回空
      }
    }
    return <String, dynamic>{};
  }
}
