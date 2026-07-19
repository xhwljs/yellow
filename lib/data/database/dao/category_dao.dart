import 'package:floor/floor.dart';
import 'package:videohub/data/models/category.dart';

@dao
abstract class CategoryDao {
  @Query('SELECT * FROM Category ORDER BY id ASC')
  Future<List<Category>> findAll();

  @Query('SELECT * FROM Category WHERE id = :id')
  Future<Category?> findById(int id);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertAll(List<Category> categories);

  @Query('DELETE FROM Category')
  Future<void> deleteAll();

  @transaction
  Future<void> replaceAll(List<Category> categories) async {
    await deleteAll();
    await insertAll(categories);
  }
}
