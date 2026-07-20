import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/database/app_database.dart';
import 'package:yellow_depot/data/models/play_history.dart';

/// 播放历史 Repository
///
/// 永久保存视频播放历史记录（按时间倒序）。
/// 提供 upsert、查询、删除、自动裁剪等操作。
class HistoryRepository {
  final AppDatabase _db;

  HistoryRepository(this._db);

  /// 获取全部历史（默认 500 条，已补全 @ignore 详情字段）
  ///
  /// 详情字段（durationText/playCount/likeCount/updateTime）从 [VideoDao]
  /// 缓存按 videoId 批量补全，避免触发 schema migration：
  /// - VideoDao 命中 → 显示完整详情
  /// - VideoDao 未命中 → 字段为空，UI 自动隐藏对应行
  ///
  /// 旧实现每条记录都 findById 一次（N+1），改为一次 IN 查询批量补全。
  Future<List<PlayHistory>> getAllHistory({int limit = 500}) async {
    final list = await _db.historyDao.findAll(limit);
    if (list.isEmpty) return const [];

    // 批量查询 Video 详情，一次 SQL 拿全
    final videoIds = list.map((h) => h.videoId).toList();
    final videos = await _db.videoDao.findByIds(videoIds);
    final videoMap = {for (final v in videos) v.id: v};

    return list.map((h) {
      final v = videoMap[h.videoId];
      if (v == null) return h;
      return h.withDetail(
        durationText: v.duration,
        playCount: v.playCount,
        likeCount: v.likeCount,
        updateTime: v.updateTime,
      );
    }).toList();
  }

  /// 分页获取历史
  Future<List<PlayHistory>> getHistoryPage({
    int limit = 20,
    int offset = 0,
  }) async {
    return _db.historyDao.findPage(limit, offset);
  }

  /// 获取单条历史
  Future<PlayHistory?> getByVideoId(String videoId) async {
    return _db.historyDao.findByVideoId(videoId);
  }

  /// 更新或插入播放记录
  ///
  /// 自动裁剪超过 [AppConstants.historyMaxRecords] 的旧记录。
  /// 为避免每秒 upsert 都跑 trimOld（DB 写放大），仅当当前条数超过
  /// 阈值的 1.2 倍时才触发裁剪。
  Future<void> upsertHistory({
    required String videoId,
    required String title,
    required String coverUrl,
    required int categoryId,
    required int positionMs,
    required int durationMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.historyDao.upsert(
      PlayHistory(
        videoId: videoId,
        title: title,
        coverUrl: coverUrl,
        categoryId: categoryId,
        positionMs: positionMs,
        durationMs: durationMs,
        updatedAt: now,
      ),
    );

    // 仅在超阈值 1.2 倍时才裁剪，避免每秒 upsert 都跑 DELETE
    // （详情页 _historySaveInterval = 5s，长时间播放会触发多次 upsert）
    final count = (await _db.historyDao.count()) ?? 0;
    if (count > (AppConstants.historyMaxRecords * 1.2).ceil()) {
      await _db.historyDao.trimOld(AppConstants.historyMaxRecords);
    }
    appLogger.d(
      '更新播放历史: $videoId progress=${positionMs / (durationMs > 0 ? durationMs : 1)}',
    );
  }

  /// 删除单条历史
  Future<void> deleteByVideoId(String videoId) async {
    await _db.historyDao.deleteByVideoId(videoId);
  }

  /// 清空所有历史
  Future<void> clearAll() async {
    await _db.historyDao.deleteAll();
  }
}
