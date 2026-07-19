import 'package:videohub/core/constants/app_constants.dart';

/// API 端点定义
class ApiEndpoints {
  ApiEndpoints._();

  static String get base => AppConstants.baseUrl;

  /// 分类列表（解析首页导航菜单）
  static String get categories => base;

  /// 分类视频列表
  /// 第一页: /vodtype/{categoryId}.html
  /// 分页:   /vodtype/{categoryId}-{page}.html
  static String categoryVideos(int categoryId, [int? page]) {
    if (page == null || page <= 1) {
      return '$base/vodtype/$categoryId.html';
    }
    return '$base/vodtype/$categoryId-$page.html';
  }

  /// 视频详情
  ///
  /// 站点当前结构（2026）：/v5/{aid}-{sid}-{nid}.html
  /// 其中 [videoId] 应为复合 ID，格式 `aid-sid-nid`（如 `230754-1-1`），
  /// 由列表页 `/v5/...` href 直接解析得到。
  ///
  /// 兼容旧路径 /voddetail/{id}.html（保留以防站点回退）。
  static String videoDetail(String videoId) {
    if (videoId.contains('-')) {
      // 复合 ID：aid-sid-nid
      return '$base/v5/$videoId.html';
    }
    // 单 ID（旧路径，兼容）
    return '$base/voddetail/$videoId.html';
  }

  /// 解密播放地址（POST）
  /// /static/count.php
  static String get playUrlDecrypt => '$base/static/count.php';

  /// 首页推荐
  static String get home => base;
}
