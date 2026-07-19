import 'package:html/parser.dart';
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/category.dart';

/// 分类列表解析器
///
/// 解析首页导航菜单，提取所有视频分类。
class CategoryParser {
  CategoryParser._();

  /// 从首页 HTML 解析分类列表
  ///
  /// 选择器：基于通用模板站点的 .stui-header__menu / nav / .nav-menu
  /// 兼容多种模板结构。
  static List<Category> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = parse(html);

      // 优先尝试 .stui-header__menu (macCMS 标准)
      var items = doc.querySelectorAll('.stui-header__menu li a');
      // 兼容：标准 nav ul li a
      if (items.isEmpty) {
        items = doc.querySelectorAll('nav ul li a');
      }
      // 兼容：.nav-menu
      if (items.isEmpty) {
        items = doc.querySelectorAll('.nav-menu a, .navbar-nav a');
      }

      final categories = <Category>[];
      final seenIds = <int>{};

      for (final element in items) {
        final href = element.attributes['href'] ?? '';
        final name = element.text.trim();
        if (name.isEmpty || href.isEmpty) continue;

        final id = _extractCategoryId(href);
        if (id == null || seenIds.contains(id)) continue;

        seenIds.add(id);
        categories.add(Category(
          id: id,
          name: name,
          url: href,
          count: 0,
        ));
      }

      return categories;
    } catch (e) {
      throw ParseException(
        '分类列表解析失败',
        selector: '.stui-header__menu',
        cause: e,
      );
    }
  }

  static int? _extractCategoryId(String href) {
    // /vodtype/123.html → 123
    final match = RegExp(r'vodtype/(\d+)').firstMatch(href);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
