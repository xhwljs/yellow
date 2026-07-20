import 'package:floor/floor.dart';
import 'package:yellow_depot/data/models/play_history.dart';

@dao
abstract class HistoryDao {
  @Query('SELECT * FROM PlayHistory ORDER BY updatedAt DESC LIMIT :limit')
  Future<List<PlayHistory>> findAll(int limit);

  @Query(
    'SELECT * FROM PlayHistory ORDER BY updatedAt DESC LIMIT :limit OFFSET :offset',
  )
  Future<List<PlayHistory>> findPage(int limit, int offset);

  @Query('SELECT * FROM PlayHistory WHERE videoId = :videoId')
  Future<PlayHistory?> findByVideoId(String videoId);

  /// 当前历史总条数 — 用于 [HistoryRepository.upsertHistory] 判断
  /// 是否需要触发 trimOld（仅在超阈值 1.2 倍时才裁剪，避免每次 upsert 都写 DELETE）。
  @Query('SELECT COUNT(*) FROM PlayHistory')
  Future<int?> count();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsert(PlayHistory history);

  @Query('DELETE FROM PlayHistory WHERE videoId = :videoId')
  Future<void> deleteByVideoId(String videoId);

  @Query(
    'DELETE FROM PlayHistory WHERE videoId NOT IN ('
    'SELECT videoId FROM PlayHistory ORDER BY updatedAt DESC LIMIT :keepCount)',
  )
  Future<void> trimOld(int keepCount);

  @Query('DELETE FROM PlayHistory')
  Future<void> deleteAll();
}
