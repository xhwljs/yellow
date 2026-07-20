import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/favorite.dart';

/// 收藏 Repository
///
/// 永久保存视频收藏列表。
///
/// **详情字段补全**（避免 schema migration）：
/// Favorite 表只持久化基础字段（videoId/title/coverUrl/categoryId/createdAt），
/// 详情展示字段（duration/playCount/likeCount/updateTime）是 @ignore，
/// 加载时从 [VideoDao] 缓存按 videoId 批量补全。
/// - VideoDao 命中 → 显示完整详情
/// - VideoDao 未命中 → 字段为空，UI 自动隐藏对应行
class FavoriteRepository {
  final AppDatabase _db;

  FavoriteRepository(this._db);

  /// 获取全部收藏（按创建时间倒序，已补全 @ignore 详情字段）
  Future<List<Favorite>> getAllFavorites() async {
    final favs = await _db.favoriteDao.findAll();
    if (favs.isEmpty) return const [];

    // 批量从 VideoDao 查询详情并补全 @ignore 字段
    final enriched = <Favorite>[];
    for (final fav in favs) {
      final video = await _db.videoDao.findById(fav.videoId);
      if (video != null) {
        enriched.add(
          fav.withDetail(
            duration: video.duration,
            playCount: video.playCount,
            likeCount: video.likeCount,
            updateTime: video.updateTime,
          ),
        );
      } else {
        enriched.add(fav);
      }
    }
    return enriched;
  }

  /// 检查是否已收藏
  Future<bool> isFavorited(String videoId) async {
    return (await _db.favoriteDao.exists(videoId)) ?? false;
  }

  /// 添加收藏
  Future<void> addFavorite({
    required String videoId,
    required String title,
    required String coverUrl,
    required int categoryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.favoriteDao.insert(
      Favorite(
        videoId: videoId,
        title: title,
        coverUrl: coverUrl,
        categoryId: categoryId,
        createdAt: now,
      ),
    );
    appLogger.i('已收藏: $videoId');
  }

  /// 取消收藏
  Future<void> removeFavorite(String videoId) async {
    await _db.favoriteDao.deleteByVideoId(videoId);
    appLogger.i('已取消收藏: $videoId');
  }

  /// 切换收藏状态
  ///
  /// 返回 true=已收藏，false=已取消
  Future<bool> toggleFavorite({
    required String videoId,
    required String title,
    required String coverUrl,
    required int categoryId,
  }) async {
    final exists = await isFavorited(videoId);
    if (exists) {
      await removeFavorite(videoId);
      return false;
    } else {
      await addFavorite(
        videoId: videoId,
        title: title,
        coverUrl: coverUrl,
        categoryId: categoryId,
      );
      return true;
    }
  }

  /// 收藏总数
  Future<int> count() async {
    return (await _db.favoriteDao.count()) ?? 0;
  }
}
