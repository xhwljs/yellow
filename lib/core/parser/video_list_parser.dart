import 'package:html/parser.dart';
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/video.dart';

/// 视频列表解析器
///
/// 解析 .stui-vodlist__box 元素，提取视频元数据。
class VideoListParser {
  final int categoryId;

  VideoListParser({required this.categoryId});

  /// 从分类页 HTML 解析视频列表
  List<Video> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = parse(html);
      final items = doc.querySelectorAll('.stui-vodlist__box');

      return items
          .map((element) {
            final link = element.querySelector('a');
            final img = element.querySelector('img');
            final detail = element.querySelector('.stui-vodlist__detail');
            final picText = element.querySelector('.pic-text');

            final href = link?.attributes['href'] ?? '';
            final id = _extractVideoId(href);

            return Video(
              id: id,
              title: detail?.querySelector('h4 a')?.text.trim() ??
                  link?.text.trim() ??
                  '',
              coverUrl: img?.attributes['data-original'] ??
                  img?.attributes['src'] ??
                  '',
              duration: picText?.text.trim() ?? '',
              updateTime: '',
              playCount: 0,
              likeCount: 0,
              categoryId: categoryId,
            );
          })
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

  /// 提取总页数（用于分页加载）
  int parseTotalPages(String html) {
    try {
      final doc = parse(html);
      // 通用模板站点的分页结构
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

  String _extractVideoId(String href) {
    // /voddetail/123.html → 123
    final match = RegExp(r'voddetail/([A-Za-z0-9]+)').firstMatch(href);
    return match?.group(1) ?? '';
  }
}
