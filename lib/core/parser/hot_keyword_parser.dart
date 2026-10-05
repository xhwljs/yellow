import 'package:html/parser.dart' as html_parser;

/// 热门搜索词条解析器
///
/// 从站点页面（推荐用 /topic.html）的 header 区解析快捷搜索词条。
///
/// 站点结构（实测 2026-09）：
/// - 每个服务端渲染页面的 header 都有一组站方运营配置的快捷搜索链接：
///   `<a href="/vodsearch/{词条URL编码}-------------.html">词条</a>`
///   （关键字后固定 13 个连字符）
/// - 词条 URL 编码（中文/特殊字符），解码后即为可展示关键词
/// - topic 正文区块（.zhuanti-list）与 actor 页演员列表均为 JS 动态渲染，
///   服务端 HTML 无数据，因此 header 词条是唯一稳定数据源
class HotKeywordParser {
  HotKeywordParser._();

  /// 词条链接模式：`/vodsearch/{词条}-------------.html`（13 个连字符）
  static final RegExp _searchLinkPattern =
      RegExp(r'^/vodsearch/(.+?)-{13}\.html$');

  /// 解析页面中的热门搜索词条
  ///
  /// - 遍历所有 `<a>`，href 匹配快捷搜索模式即提取
  /// - 词条 URL 解码 + trim，空值跳过
  /// - 去重保序（首次出现优先）
  /// - 最多返回 [maxCount] 条（站点当前 15 条，预留余量）
  static List<String> parse(String html, {int maxCount = 20}) {
    if (html.trim().isEmpty) return const [];

    final document = html_parser.parse(html);
    final anchors = document.querySelectorAll('a[href]');
    if (anchors.isEmpty) return const [];

    final keywords = <String>[];
    for (final anchor in anchors) {
      final href = anchor.attributes['href'] ?? '';
      final match = _searchLinkPattern.firstMatch(href);
      if (match == null) continue;

      var keyword = '';
      try {
        keyword = Uri.decodeComponent(match.group(1) ?? '');
      } catch (_) {
        // URL 解码失败（非法编码序列）跳过该词条
        continue;
      }
      keyword = keyword.trim();
      if (keyword.isEmpty || keywords.contains(keyword)) continue;

      keywords.add(keyword);
      if (keywords.length >= maxCount) break;
    }
    return keywords;
  }
}
