import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/play_history.dart';

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
  Future<List<PlayHistory>> getAllHistory({int limit = 500}) async {
    final list = await _db.historyDao.findAll(limit);
    if (list.isEmpty) return const [];

    final enriched = <PlayHistory>[];
    for (final h in list) {
      final video = await _db.videoDao.findById(h.videoId);
      if (video != null) {
        enriched.add(
          h.withDetail(
            durationText: video.duration,
            playCount: video.playCount,
            likeCount: video.likeCount,
            updateTime: video.updateTime,
          ),
        );
      } else {
        enriched.add(h);
      }
    }
    return enriched;
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

    // 自动裁剪
    await _db.historyDao.trimOld(AppConstants.historyMaxRecords);
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
