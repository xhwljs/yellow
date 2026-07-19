import 'package:html/parser.dart' as html_parser;
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/category.dart';

/// 分类列表解析器
///
/// 解析首页导航菜单，提取所有视频分类。
///
/// **过滤规则**：默认排除"成人动漫"分类（用户需求 — 取消动漫采集）。
/// 通过分类名匹配关键字 `动漫`/`anime` 判定。
class CategoryParser {
  CategoryParser._();

  /// 需要过滤的分类名关键字（不区分大小写）
  static const _blockedKeywords = ['动漫', 'anime', 'cartoon'];

  /// 从首页 HTML 解析分类列表
  ///
  /// 选择器：基于通用模板站点的 .stui-header__menu / nav / .nav-menu
  /// 兼容多种模板结构。
  static List<Category> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = html_parser.parse(html);

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

        // 过滤动漫类分类
        if (_isBlocked(name)) {
          continue;
        }

        seenIds.add(id);
        categories.add(
          Category(
            id: id,
            name: name,
            url: href,
            count: 0,
          ),
        );
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

  /// 判断分类名是否应被过滤（动漫类）
  static bool _isBlocked(String name) {
    final lower = name.toLowerCase();
    for (final kw in _blockedKeywords) {
      if (lower.contains(kw.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 对已存在的分类列表做兜底过滤
  ///
  /// 用于过滤历史缓存中可能存在的动漫分类。
  static List<Category> filterBlocked(List<Category> categories) {
    return categories.where((c) => !_isBlocked(c.name)).toList();
  }

  static int? _extractCategoryId(String href) {
    // /vodtype/123.html → 123
    final match = RegExp(r'vodtype/(\d+)').firstMatch(href);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
