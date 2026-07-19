import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/video.dart';

/// 视频列表解析器
///
/// 站点当前结构（2026）：
/// - 列表项选择器 `.stui-vodlist__box`（与文档一致）
/// - 真实视频的 `<a>` href 为 `/v5/{aid}-{sid}-{nid}.html`
/// - 广告 `<a>` href 为 `https://外站.com`，需过滤
/// - 封面在 `<a>` 标签的 `data-original` 属性（不在 `<img>` 上）
/// - 时长在 `.pic-text`（位于 `<a>` 内）
/// - 标题在 `.stui-vodlist__detail h4 a`
class VideoListParser {
  final int categoryId;

  VideoListParser({required this.categoryId});

  /// 从分类页 HTML 解析视频列表
  List<Video> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = html_parser.parse(html);
      final items = doc.querySelectorAll('.stui-vodlist__box');

      return items
          .map((element) => _parseItem(element))
          .whereType<Video>()
          .where((v) => v.id.isNotEmpty)
          .toList();
    } catch (e) {
      throw ParseException(
        '视频列表解析失败',
        selector: '.stui-vodlist__box',
        cause: e,
      );
    }
  }

  /// 解析单个 `.stui-vodlist__box` 元素
  ///
  /// 返回 null 表示该项是广告（href 不是 `/v5/`）。
  Video? _parseItem(dom.Element element) {
    // 优先取指向 /v5/ 的 a 标签（真实视频），降级到旧路径 /voddetail/
    final link = element.querySelector('a[href*="/v5/"]') ??
        element.querySelector('a[href*="/voddetail/"]');
    if (link == null) return null;

    final href = link.attributes['href'] ?? '';
    final id = _extractVideoId(href);
    if (id.isEmpty) {
      return null;
    }

    // 封面优先取 a[data-original]，降级到 img[data-original] / img[src]
    final coverUrl = link.attributes['data-original'] ??
        element.querySelector('img')?.attributes['data-original'] ??
        element.querySelector('img')?.attributes['src'] ??
        '';

    // 标题：优先 .stui-vodlist__detail h4 a，降级到 a 的 title 属性 / 文本
    final detailEl = element.querySelector('.stui-vodlist__detail');
    final title = detailEl?.querySelector('h4 a')?.text.trim() ??
        link.attributes['title']?.trim() ??
        link.text.trim();

    // 时长在 a 内的 .pic-text
    final picText =
        link.querySelector('.pic-text') ?? element.querySelector('.pic-text');
    final duration = picText?.text.trim() ?? '';

    // 解析播放数 / 喜欢数 / 更新时间（在 .stui-vodlist__detail .sub 内）
    final subEl = detailEl?.querySelector('.sub');
    final playCount = _extractNumber(subEl, 'fa-eye');
    final likeCount = _extractNumber(subEl, 'fa-heart');
    // .sub 内文本最后一段通常是 MM-DD 更新时间
    final updateTime = _extractUpdateTime(subEl);

    return Video(
      id: id,
      title: title,
      coverUrl: coverUrl,
      duration: duration,
      updateTime: updateTime,
      playCount: playCount,
      likeCount: likeCount,
      categoryId: categoryId,
    );
  }

  /// 提取总页数（用于分页加载）
  int parseTotalPages(String html) {
    try {
      final doc = html_parser.parse(html);
      final pagination = doc.querySelector('.stui-page, .pagination, .page');
      if (pagination == null) return 1;

      final links = pagination.querySelectorAll('a');
      var maxPage = 1;
      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        final match = RegExp(r'-(\d+)\.html').firstMatch(href);
        if (match != null) {
          final page = int.tryParse(match.group(1) ?? '1') ?? 1;
          if (page > maxPage) maxPage = page;
        }
      }
      return maxPage;
    } catch (_) {
      return 1;
    }
  }

  /// 提取 videoId（支持 `/v5/{aid}-{sid}-{nid}.html` 与旧 `/voddetail/{id}.html`）
  ///
  /// 返回值：
  /// - 新结构：`230754-1-1`（aid-sid-nid 复合 ID）
  /// - 旧结构：`abc123`
  /// - 无匹配：空字符串
  String _extractVideoId(String href) {
    // 新结构：/v5/230754-1-1.html
    final v5Match = RegExp(r'/v5/([A-Za-z0-9_-]+)\.html').firstMatch(href);
    if (v5Match != null) return v5Match.group(1) ?? '';

    // 旧结构：/voddetail/xxx.html
    final vodMatch = RegExp(r'voddetail/([A-Za-z0-9]+)').firstMatch(href);
    if (vodMatch != null) return vodMatch.group(1) ?? '';

    return '';
  }

  /// 从 `.sub` 元素中提取带指定 fa 图标的数字
  ///
  /// 例：`<span class="pull-right"><i class="fa fa-eye"></i> 61753 </span>` → 61753
  int _extractNumber(dom.Element? subEl, String faClass) {
    if (subEl == null) return 0;
    try {
      // 找带指定 class 的 i 元素所在的 span
      final spans = subEl.querySelectorAll('span.pull-right, span.number');
      for (final span in spans) {
        final i = span.querySelector('i.fa.$faClass');
        if (i != null) {
          final text = span.text.replaceAll(RegExp(r'[^\d]'), '');
          return int.tryParse(text) ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// 提取更新时间（MM-DD 或 YYYY-MM-DD）
  String _extractUpdateTime(dom.Element? subEl) {
    if (subEl == null) return '';
    try {
      final text = subEl.text;
      // 匹配 MM-DD 或 YYYY-MM-DD
      final match =
          RegExp(r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}-\d{1,2})').firstMatch(text);
      return match?.group(1) ?? '';
    } catch (_) {}
    return '';
  }
}
