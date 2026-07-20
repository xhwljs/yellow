import 'package:shared_preferences/shared_preferences.dart';
import 'package:videohub/core/constants/app_constants.dart';
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
///
/// **catalog/nav 分组**（用户需求）：
/// - "目录"区块分类（`.stui-pannel__menu`，isCatalog=true）→ 右下角卷帘菜单
/// - "导航菜单"分类（`.stui-header__menu` 中独有，isCatalog=false）→ 顶部 Tab + 推荐 sections
///
/// 由于 [Category.isCatalog] 是 `@ignore` 字段不持久化到数据库，
/// 启动时从数据库读取的 Category 默认 isCatalog=false。
/// 通过 SharedPreferences 缓存 catalog id 集合（[AppConstants.keyCatalogCategoryIds]），
/// 在内存中用 [CategoryParser.markCatalog] 重建 isCatalog 分组。
class CategoryRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  CategoryRepository(this._apiService, this._db);

  /// 获取所有分类（catalog + nav 合并）
  ///
  /// 已用 [CategoryParser.markCatalog] 在内存中标记 isCatalog 字段。
  /// UI 层可通过 [catalogCategories] / [navCategories] getter 分组使用。
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // 缓存优先
    if (!forceRefresh) {
      final cached = await _db.categoryDao.findAll();
      if (cached.isNotEmpty) {
        // 兜底过滤：清理历史缓存中的动漫分类
        final filtered = CategoryParser.filterBlocked(cached);
        // 用 SharedPreferences 中的 catalog_ids 给内存 Category 标记 isCatalog
        final catalogIds = await _loadCatalogIds();
        final marked = CategoryParser.markCatalog(filtered, catalogIds);
        appLogger.d(
          '使用缓存分类: ${marked.length} 条（catalog=${catalogIds.length}, '
          'nav=${marked.length - catalogIds.length}）',
        );
        return marked;
      }
    }

    // 拉取远程
    appLogger.i('拉取远程分类列表');
    final html = await _apiService.fetchHomeHtml();
    final categories = CategoryParser.parse(html);

    if (categories.isNotEmpty) {
      await _db.categoryDao.replaceAll(categories);
      // 同步 catalog_ids 到 SharedPreferences
      final catalogIds = categories.where((c) => c.isCatalog).map((c) => c.id).toSet();
      await _saveCatalogIds(catalogIds);
      appLogger.i(
        '缓存分类: ${categories.length} 条（catalog=${catalogIds.length}, '
        'nav=${categories.length - catalogIds.length}）',
      );
    }

    return categories;
  }

  /// 从 SharedPreferences 读取 catalog id 集合
  ///
  /// 格式：逗号分隔的 int 字符串，如 "8,9,10,15,21,26,7"
  Future<Set<int>> _loadCatalogIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyCatalogCategoryIds);
    if (raw == null || raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  /// 把 catalog id 集合写入 SharedPreferences
  Future<void> _saveCatalogIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyCatalogCategoryIds,
      ids.join(','),
    );
  }
}
