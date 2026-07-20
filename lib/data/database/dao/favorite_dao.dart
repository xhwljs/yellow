import 'package:floor/floor.dart';
import 'package:yellow_depot/data/models/favorite.dart';

@dao
abstract class FavoriteDao {
  @Query('SELECT * FROM Favorite ORDER BY createdAt DESC')
  Future<List<Favorite>> findAll();

  @Query('SELECT * FROM Favorite WHERE videoId = :videoId')
  Future<Favorite?> findByVideoId(String videoId);

  @Query('SELECT EXISTS(SELECT 1 FROM Favorite WHERE videoId = :videoId)')
  Future<bool?> exists(String videoId);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insert(Favorite favorite);

  @Query('DELETE FROM Favorite WHERE videoId = :videoId')
  Future<void> deleteByVideoId(String videoId);

  @Query('SELECT COUNT(*) FROM Favorite')
  Future<int?> count();
}
