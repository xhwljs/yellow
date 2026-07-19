import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/favorite.dart';

/// 收藏 Repository
///
/// 永久保存视频收藏列表。
class FavoriteRepository {
  final AppDatabase _db;

  FavoriteRepository(this._db);

  /// 获取全部收藏（按创建时间倒序）
  Future<List<Favorite>> getAllFavorites() async {
    return _db.favoriteDao.findAll();
  }

  /// 检查是否已收藏
  Future<bool> isFavorited(String videoId) async {
    return _db.favoriteDao.exists(videoId);
  }

  /// 添加收藏
  Future<void> addFavorite({
    required String videoId,
    required String title,
    required String coverUrl,
    required int categoryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.favoriteDao.insert(Favorite(
      videoId: videoId,
      title: title,
      coverUrl: coverUrl,
      categoryId: categoryId,
      createdAt: now,
    ));
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
