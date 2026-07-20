import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/parser/video_detail_parser.dart';
import 'package:yellow_depot/core/parser/video_list_parser.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/database/app_database.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/models/video_detail.dart';

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

  /// 缓存单条视频到 Video 表（用于详情页补全详情字段）
  ///
  /// 收藏/播放历史列表加载时，会从 VideoDao 按 videoId 查询详情字段
  /// （duration/playCount/likeCount/updateTime）补全到 Favorite/PlayHistory
  /// 的 @ignore 字段。详情页加载后调用此方法同步缓存当前视频，
  /// 保证用户收藏或播放后，下次打开收藏/历史列表能立即看到完整详情。
  ///
  /// 注意：用 OnConflictStrategy.replace，已存在则覆盖（保持最新数据）。
  Future<void> cacheVideo(Video video) async {
    await _db.videoDao.insert(video);
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

  /// 搜索视频
  ///
  /// 调用站点 /vodsearch/{keyword}-------------.html 接口，
  /// 解析返回的 HTML（结构与分类页一致，复用 VideoListParser）。
  /// 搜索结果不缓存（实时性要求 + 节省存储）。
  ///
  /// [keyword] 搜索关键字（不为空才会请求）
  /// [page] 页码，从 1 开始
  Future<List<Video>> searchVideos(
    String keyword, {
    int page = 1,
  }) async {
    if (keyword.trim().isEmpty) return const [];
    appLogger.i('搜索视频 keyword="$keyword" page=$page');
    final html = await _apiService.searchVideosHtml(keyword, page);
    // 搜索结果的 categoryId 用 0 标记（不属于任何分类）
    final parser = VideoListParser(categoryId: 0);
    return parser.parse(html);
  }
}
