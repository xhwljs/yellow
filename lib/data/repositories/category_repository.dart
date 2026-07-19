import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/parser/category_parser.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/category.dart';

/// 分类 Repository
///
/// 优先读本地缓存，缓存失效或不存在时拉取远程数据并更新缓存。
class CategoryRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  CategoryRepository(this._apiService, this._db);

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // 缓存优先
    if (!forceRefresh) {
      final cached = await _db.categoryDao.findAll();
      if (cached.isNotEmpty) {
        appLogger.d('使用缓存分类: ${cached.length} 条');
        return cached;
      }
    }

    // 拉取远程
    appLogger.i('拉取远程分类列表');
    final html = await _apiService.fetchHomeHtml();
    final categories = CategoryParser.parse(html);

    if (categories.isNotEmpty) {
      await _db.categoryDao.replaceAll(categories);
      appLogger.i('缓存分类: ${categories.length} 条');
    }

    return categories;
  }
}
