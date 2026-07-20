import 'package:yellow_depot/core/constants/app_constants.dart';
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
///
/// **TTL 策略**：[AppConstants.cacheMaxAgeMinutes] 控制缓存有效期。
/// 旧实现仅判断「缓存是否存在」永不过期，导致用户离线后看到的还是旧数据。
/// 现在用进程内时间戳校验，过期则丢弃缓存走网络。
class VideoRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  /// 分类首页缓存时间戳（key: categoryId）
  ///
  /// 配合 [AppConstants.cacheMaxAgeMinutes] 判断缓存是否过期。
  /// 进程内 Map 即可（DB 重启时缓存重建，无需持久化时间戳）。
  final Map<int, DateTime> _cacheTimestamps = {};

  VideoRepository(this._apiService, this._db);

  /// 判断 categoryId 的缓存是否过期
  ///
  /// - 无时间戳记录 → 视为过期（首次加载或进程重启）
  /// - 当前时间 - 缓存时间 > [AppConstants.cacheMaxAgeMinutes] 分钟 → 过期
  bool _isCacheStale(int categoryId) {
    final cachedAt = _cacheTimestamps[categoryId];
    if (cachedAt == null) return true;
    final age = DateTime.now().difference(cachedAt);
    return age > Duration(minutes: AppConstants.cacheMaxAgeMinutes);
  }

  /// 获取分类视频列表（带分页）
  Future<List<Video>> getCategoryVideos(
    int categoryId, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    // 仅缓存首页（避免分页数据过时）
    if (!forceRefresh && page == 1) {
      final cached = await _db.videoDao.findByCategoryId(categoryId);
      if (cached.isNotEmpty && !_isCacheStale(categoryId)) {
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
      _cacheTimestamps[categoryId] = DateTime.now();
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
  /// **重要**：使用合并策略而非覆盖：
  /// - VideoDetailParser 不一定提取 playCount/likeCount/updateTime
  ///   （取决于详情页 HTML 结构，没有时回退到 0/''）
  /// - VideoListParser 从 .stui-vodlist__detail .sub 提取这些字段
  /// - 如果直接 replace，详情页缓存会覆盖列表页缓存的正确数据
  /// - 修复：先查现有 Video，把 detail.video 中为空/为 0 的字段
  ///   用现有数据补全，然后再写入
  ///
  /// 返回合并后的 [Video]，调用方可直接用于回填 detail.value.video，
  /// 让 UI 立即显示播放量/收藏数/发布时间等元信息。
  Future<Video> cacheVideo(Video video) async {
    final existing = await _db.videoDao.findById(video.id);
    final merged = video.copyWith(
      // 列表页缓存的 playCount/likeCount 大于 0 时保留，不覆盖为 0
      playCount: (video.playCount > 0)
          ? video.playCount
          : (existing?.playCount ?? 0),
      likeCount: (video.likeCount > 0)
          ? video.likeCount
          : (existing?.likeCount ?? 0),
      // 列表页缓存的 updateTime 非空时保留，不覆盖为空
      updateTime: video.updateTime.isNotEmpty
          ? video.updateTime
          : (existing?.updateTime ?? ''),
      // 列表页缓存的 duration 非空时保留
      duration: video.duration.isNotEmpty
          ? video.duration
          : (existing?.duration ?? ''),
      // 列表页缓存的 coverUrl 非空时保留
      coverUrl: video.coverUrl.isNotEmpty
          ? video.coverUrl
          : (existing?.coverUrl ?? ''),
      // 列表页缓存的 title 非空时保留
      title: video.title.isNotEmpty
          ? video.title
          : (existing?.title ?? video.title),
    );
    await _db.videoDao.insert(merged);
    return merged;
  }

  /// 通过 ids 批量查询
  ///
  /// 旧实现循环 findById 是 N 次查询，改为一次 IN 查询。
  Future<List<Video>> getVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _db.videoDao.findByIds(ids);
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
