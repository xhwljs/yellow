import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/category.dart';

/// 分类列表解析器
///
/// 解析首页**所有**分类入口：
/// 1. 顶部导航菜单 `.stui-header__menu li a`（macCMS 标准）
/// 2. **"目录"区块** `.stui-pannel__menu li a`（站点首页目录卡片，
///    含 `<span class="count">N</span>` 视频数量，更精确）
///
/// 合并去重：相同 ID 的分类以"目录"区块优先（含 count 视频数量）。
///
/// **过滤规则**：默认排除"成人动漫"分类（用户需求 — 取消动漫采集）。
/// 通过分类名匹配关键字 `动漫`/`anime` 判定。
class CategoryParser {
  CategoryParser._();

  /// 需要过滤的分类名关键字（不区分大小写）
  static const _blockedKeywords = ['动漫', 'anime', 'cartoon'];

  /// 从首页 HTML 解析分类列表
  ///
  /// 优先解析"目录"区块（含 count），再补充导航菜单中的其它分类。
  static List<Category> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = html_parser.parse(html);

      final categories = <Category>[];
      final seenIds = <int>{};

      // 1. 优先解析"目录"区块（.stui-pannel__menu）— 含 count 视频数量
      //
      // HTML 结构（实测 2026-07-19）：
      // <h3 class="title">目录</h3>
      // <ul class="stui-pannel__menu clearfix">
      //   <li><a href="/vodtype/8.html">
      //     <span class="count pull-right">4827</span>无码中文字幕
      //   </a></li>
      //   ...
      // </ul>
      //
      // 这些分类 isCatalog=true，仅用于右下角悬浮目录卷帘菜单。
      final catalogItems = doc.querySelectorAll('.stui-pannel__menu li a');
      for (final element in catalogItems) {
        final href = element.attributes['href'] ?? '';
        final id = _extractCategoryId(href);
        if (id == null || seenIds.contains(id)) continue;

        // 提取 count（<span class="count pull-right">4827</span>）
        final countText = element.querySelector('.count')?.text.trim() ?? '0';
        final count = int.tryParse(countText) ?? 0;

        // 提取分类名：遍历直接子节点，跳过 span 节点，取剩余 TextNode 内容
        // element.text 会包含 "4827无码中文字幕"，需剔除 count span
        final name = _extractCategoryName(element);

        if (name.isEmpty) continue;
        if (_isBlocked(name)) continue;

        seenIds.add(id);
        categories.add(
          Category(
            id: id,
            name: name,
            url: href,
            count: count,
            isCatalog: true,
          ),
        );
      }

      // 2. 补充顶部导航菜单（.stui-header__menu）中"目录"区块没有的分类
      //    导航菜单的 count 通常为 0，仅用于补充缺失的入口。
      //    这些分类 isCatalog=false，用于首页顶部 Tab + 推荐 sections。
      final navItems = doc.querySelectorAll('.stui-header__menu li a');
      for (final element in navItems) {
        final href = element.attributes['href'] ?? '';
        final id = _extractCategoryId(href);
        if (id == null || seenIds.contains(id)) continue;

        final name = _extractCategoryName(element);
        if (name.isEmpty || href.isEmpty) continue;
        if (_isBlocked(name)) continue;

        seenIds.add(id);
        categories.add(
          Category(
            id: id,
            name: name,
            url: href,
            count: 0,
            isCatalog: false,
          ),
        );
      }

      // 3. 兜底：如果上面两个选择器都没匹配到（模板差异），
      //    尝试标准 nav ul li a / .nav-menu a
      if (categories.isEmpty) {
        var items = doc.querySelectorAll('nav ul li a');
        if (items.isEmpty) {
          items = doc.querySelectorAll('.nav-menu a, .navbar-nav a');
        }
        for (final element in items) {
          final href = element.attributes['href'] ?? '';
          final name = _extractCategoryName(element);
          if (name.isEmpty || href.isEmpty) continue;

          final id = _extractCategoryId(href);
          if (id == null || seenIds.contains(id)) continue;
          if (_isBlocked(name)) continue;

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
      }

      return categories;
    } catch (e) {
      throw ParseException(
        '分类列表解析失败',
        selector: '.stui-pannel__menu / .stui-header__menu',
        cause: e,
      );
    }
  }

  /// 从 `<a>` 元素中提取分类名（剔除 count span 的文本）
  ///
  /// HTML 结构：
  /// `<a href="/vodtype/8.html"><span class="count pull-right">4827</span>无码中文字幕</a>`
  ///
  /// `element.text` 返回 "4827无码中文字幕"，需要移除 count span 的文本。
  /// 策略：遍历直接子节点，只取 TextNode 的 text，拼接后 trim。
  static String _extractCategoryName(dom.Element element) {
    final buf = StringBuffer();
    for (final node in element.nodes) {
      if (node is dom.Text) {
        buf.write(node.text);
      }
    }
    return buf.toString().trim();
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

  /// 仅解析首页"目录"区块（`.stui-pannel__menu`）返回 catalog 分类 id 集合
  ///
  /// 用于 [CategoryRepository] 启动时从 SharedPreferences 读取已缓存的
  /// catalog id 集合，给从数据库读取的 Category 标记 isCatalog
  /// （数据库不持久化 isCatalog 字段，需用此集合在内存中重建分组）。
  static Set<int> parseCatalogIds(String html) {
    if (html.isEmpty) return const {};
    try {
      final doc = html_parser.parse(html);
      final ids = <int>{};
      for (final element in doc.querySelectorAll('.stui-pannel__menu li a')) {
        final href = element.attributes['href'] ?? '';
        final id = _extractCategoryId(href);
        if (id == null) continue;
        final name = _extractCategoryName(element);
        if (name.isEmpty || _isBlocked(name)) continue;
        ids.add(id);
      }
      return ids;
    } catch (_) {
      return const {};
    }
  }

  /// 给从数据库读取的 Category 列表标记 isCatalog
  ///
  /// 数据库不持久化 isCatalog 字段，从数据库读取时默认 isCatalog=false。
  /// 调用此方法用 catalogIds 集合在内存中重建分组：
  /// - id 在 catalogIds 中 → isCatalog=true（来自"目录"区块）
  /// - 否则 → isCatalog=false（来自导航菜单）
  static List<Category> markCatalog(
    List<Category> categories,
    Set<int> catalogIds,
  ) {
    if (catalogIds.isEmpty) return categories;
    return categories
        .map(
          (c) => c.isCatalog || catalogIds.contains(c.id)
              ? c.copyWith(isCatalog: true)
              : c,
        )
        .toList();
  }

  static int? _extractCategoryId(String href) {
    // /vodtype/123.html → 123
    final match = RegExp(r'vodtype/(\d+)').firstMatch(href);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
