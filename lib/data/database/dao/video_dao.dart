import 'package:floor/floor.dart';
import 'package:videohub/data/models/video.dart';

@dao
abstract class VideoDao {
  @Query(
    'SELECT * FROM Video WHERE categoryId = :categoryId ORDER BY updateTime DESC',
  )
  Future<List<Video>> findByCategoryId(int categoryId);

  @Query('SELECT * FROM Video WHERE id = :id')
  Future<Video?> findById(String id);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertAll(List<Video> videos);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insert(Video video);

  @Query('DELETE FROM Video WHERE categoryId = :categoryId')
  Future<void> deleteByCategoryId(int categoryId);

  @Query('DELETE FROM Video')
  Future<void> deleteAll();

  @transaction
  Future<void> replaceByCategoryId(int categoryId, List<Video> videos) async {
    await deleteByCategoryId(categoryId);
    await insertAll(videos);
  }
}
