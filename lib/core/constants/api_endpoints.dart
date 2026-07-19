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
  /// /voddetail/{videoId}.html
  static String videoDetail(String videoId) {
    return '$base/voddetail/$videoId.html';
  }

  /// 解密播放地址（POST）
  /// /static/count.php
  static String get playUrlDecrypt => '$base/static/count.php';

  /// 首页推荐
  static String get home => base;
}
