import 'package:floor/floor.dart';
import 'package:yellow_depot/data/models/video.dart';

@dao
abstract class VideoDao {
  @Query(
    'SELECT * FROM Video WHERE categoryId = :categoryId ORDER BY updateTime DESC',
  )
  Future<List<Video>> findByCategoryId(int categoryId);

  @Query('SELECT * FROM Video WHERE id = :id')
  Future<Video?> findById(String id);

  /// 批量查询 — 用于历史/收藏列表一次性补全 @ignore 详情字段，
  /// 避免 N+1 查询（旧实现每条记录都 findById 一次）。
  ///
  /// 不存在的 id 不会出现在返回结果中，调用方需自行处理缺失项。
  /// 返回值不保证顺序与输入一致，调用方应按 id 索引使用。
  @Query('SELECT * FROM Video WHERE id IN (:ids)')
  Future<List<Video>> findByIds(List<String> ids);

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
