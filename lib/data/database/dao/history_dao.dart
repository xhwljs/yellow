import 'package:floor/floor.dart';
import 'package:videohub/data/models/play_history.dart';

@dao
abstract class HistoryDao {
  @Query('SELECT * FROM PlayHistory ORDER BY updatedAt DESC LIMIT :limit')
  Future<List<PlayHistory>> findAll([int limit = 500]);

  @Query(
    'SELECT * FROM PlayHistory ORDER BY updatedAt DESC LIMIT :limit OFFSET :offset',
  )
  Future<List<PlayHistory>> findPage([int limit = 20, int offset = 0]);

  @Query('SELECT * FROM PlayHistory WHERE videoId = :videoId')
  Future<PlayHistory?> findByVideoId(String videoId);

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
