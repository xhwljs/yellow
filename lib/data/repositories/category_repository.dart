import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/parser/category_parser.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/models/category.dart';

/// 分类 Repository
///
/// 优先读本地缓存，缓存失效或不存在时拉取远程数据并更新缓存。
///
/// **过滤规则**：动漫类分类不在采集范围（参见 [CategoryParser]）。
/// 同时对历史缓存做兜底过滤，保证旧版本缓存的动漫分类也不会展示。
class CategoryRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  CategoryRepository(this._apiService, this._db);

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // 缓存优先
    if (!forceRefresh) {
      final cached = await _db.categoryDao.findAll();
      if (cached.isNotEmpty) {
        // 兜底过滤：清理历史缓存中的动漫分类
        final filtered = CategoryParser.filterBlocked(cached);
        appLogger.d('使用缓存分类: ${filtered.length} 条（已过滤动漫）');
        return filtered;
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
