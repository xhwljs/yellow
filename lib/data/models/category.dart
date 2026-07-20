import 'package:floor/floor.dart';

/// 视频分类
///
/// **isCatalog 字段**（@ignore，不持久化到数据库）：
/// - true：来自首页"目录"区块（`.stui-pannel__menu`，含 count 视频数量），
///   仅用于右下角悬浮目录卷帘菜单展示
/// - false：来自顶部导航菜单（`.stui-header__menu`）中"目录"区块没有的分类，
///   用于首页顶部 Tab + 推荐 sections
///
/// 由于不持久化，从数据库读取的 Category 默认 isCatalog=false。
/// [CategoryRepository] 启动时从 SharedPreferences 读取 catalog_ids 集合，
/// 给内存中的 Category 标记 isCatalog，确保 UI 分组正确。
@entity
class Category {
  @primaryKey
  final int id;

  final String name;
  final String url;
  final int count; // 视频数量

  /// 是否来自"目录"区块（非持久化，纯内存标记）
  @ignore
  final bool isCatalog;

  const Category({
    required this.id,
    required this.name,
    required this.url,
    required this.count,
    this.isCatalog = false,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      url: map['url'] as String,
      count: map['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'count': count,
      };

  Category copyWith({
    int? id,
    String? name,
    String? url,
    int? count,
    bool? isCatalog,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      count: count ?? this.count,
      isCatalog: isCatalog ?? this.isCatalog,
    );
  }
}
