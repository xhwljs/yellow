import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/parser/video_detail_parser.dart';
import 'package:videohub/core/parser/video_list_parser.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/models/video_detail.dart';

/// 视频 Repository
///
/// 优先读本地缓存（30 分钟有效期），失效则拉取远程数据并更新缓存。
class VideoRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  VideoRepository(this._apiService, this._db);

  /// 获取分类视频列表（带分页）
  Future<List<Video>> getCategoryVideos(
    int categoryId, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    // 仅缓存首页（避免分页数据过时）
    if (!forceRefresh && page == 1) {
      final cached = await _db.videoDao.findByCategoryId(categoryId);
      if (cached.isNotEmpty) {
        appLogger.d('使用缓存视频列表 (categoryId=$categoryId): ${cached.length} 条');
        return cached;
      }
    }

    // 拉取远程
    appLogger.i('拉取远程视频列表 categoryId=$categoryId page=$page');
    final html = await _apiService.fetchCategoryVideosHtml(categoryId, page);
    final parser = VideoListParser(categoryId: categoryId);
    final videos = parser.parse(html);

    // 仅缓存第一页
    if (page == 1 && videos.isNotEmpty) {
      await _db.videoDao.replaceByCategoryId(categoryId, videos);
      appLogger.i('缓存视频列表: ${videos.length} 条');
    }

    return videos;
  }

  /// 获取视频详情（不缓存，实时拉取以便拿到 token）
  Future<VideoDetail> getVideoDetail(String videoId) async {
    appLogger.i('拉取视频详情 videoId=$videoId');
    final html = await _apiService.fetchVideoDetailHtml(videoId);
    return VideoDetailParser.parse(html, videoId);
  }

  /// 通过 id 单条查询（缓存优先）
  Future<Video?> getVideoById(String id) async {
    return _db.videoDao.findById(id);
  }

  /// 通过 ids 批量查询
  Future<List<Video>> getVideosByIds(List<String> ids) async {
    final result = <Video>[];
    for (final id in ids) {
      final v = await _db.videoDao.findById(id);
      if (v != null) result.add(v);
    }
    return result;
  }
}
