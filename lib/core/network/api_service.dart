import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:videohub/core/constants/api_endpoints.dart';
import 'package:videohub/core/network/dio_client.dart';

/// API 服务 — 提供所有 HTTP 接口调用
///
/// 业务层调用 Repository，Repository 调用 ApiService。
class ApiService {
  final Dio _dio;

  ApiService([Dio? dio]) : _dio = dio ?? DioClient.instance;

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

  /// POST 获取播放地址（解密接口）
  ///
  /// 参数: id, sid, nid, tk, g, x, y, dt, sw, sh, tz, t
  /// 返回: JSON {ok: boolean, u: string}
  Future<Map<String, dynamic>> postDecryptPlayUrl(
    Map<String, dynamic> params,
  ) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.playUrlDecrypt,
      data: params,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': ApiEndpoints.base,
          'X-Requested-With': 'XMLHttpRequest',
        },
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
