import 'package:html/parser.dart';
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/models/video_detail.dart';

/// 视频详情解析器
///
/// 提取标题、封面、简介、播放地址密钥参数（token），以及相关推荐视频。
class VideoDetailParser {
  VideoDetailParser._();

  /// 从视频详情页 HTML 解析 VideoDetail
  static VideoDetail parse(String html, String videoId) {
    if (html.isEmpty) {
      throw const ParseException('详情页 HTML 为空');
    }

    try {
      final doc = parse(html);

      // 标题
      final title = doc
              .querySelector(
                  '.stui-content__detail h1, .stui-pannel__head h3, h1.title')
              ?.text
              .trim() ??
          videoId;

      // 封面
      final coverImg =
          doc.querySelector('.stui-content__thumb img, .thumb img, .pic img');
      final coverUrl = coverImg?.attributes['data-original'] ??
          coverImg?.attributes['src'] ??
          '';

      // 简介
      final descEl = doc.querySelector(
        '.stui-content__detail .desc, .stui-pannel__desc, .content_detail .detail-sketch',
      );
      final description = descEl?.text.trim() ?? '';

      // 视频时长
      final duration =
          doc.querySelector('.stui-content__detail .pic-text')?.text.trim() ??
              '';

      // AK Token 提取（关键：用于解密播放地址）
      final token = _extractToken(doc);

      // sid / nid 从隐藏表单中提取
      final sid = _extractHiddenValue(doc, 'sid') ?? '1';
      final nid = _extractHiddenValue(doc, 'nid') ?? '1';

      // 相关推荐视频
      final relatedVideos = _parseRelatedVideos(doc);

      // 默认 playUrl 为空，由解密模块填充
      return VideoDetail(
        video: Video(
          id: videoId,
          title: title,
          coverUrl: coverUrl,
          duration: duration,
          updateTime: '',
          playCount: 0,
          likeCount: 0,
          categoryId: 0,
        ),
        description: description,
        playUrl: '',
        relatedVideos: relatedVideos,
        token: token,
        sid: sid,
        nid: nid,
      );
    } catch (e) {
      throw ParseException(
        '视频详情解析失败',
        selector: '.stui-content__detail',
        cause: e,
      );
    }
  }

  /// 从 script 标签中提取 AK='xxx' 的 token
  ///
  /// 示例: <script>var AK='abc123';</script>
  static String? _extractToken(dynamic doc) {
    final scripts = doc.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      // 优先匹配 AK='xxx'
      final match = RegExp(r"AK\s*=\s*'([^']+)'").firstMatch(text);
      if (match != null) return match.group(1);
      // 兼容 AK="xxx"
      final matchDouble = RegExp(r'AK\s*=\s*"([^"]+)"').firstMatch(text);
      if (matchDouble != null) return matchDouble.group(1);
    }
    return null;
  }

  /// 从隐藏表单 input 中提取值
  static String? _extractHiddenValue(dynamic doc, String name) {
    final input = doc.querySelector('input[name="$name"]');
    return input?.attributes['value'];
  }

  /// 解析相关推荐视频列表
  static List<Video> _parseRelatedVideos(dynamic doc) {
    final items = doc.querySelectorAll(
        '.stui-vodlist__bd .stui-vodlist__box, .stui-pannel_bd .stui-vodlist__box');
    return items
        .map((element) {
          final link = element.querySelector('a');
          final img = element.querySelector('img');
          final detail = element.querySelector('.stui-vodlist__detail');
          final picText = element.querySelector('.pic-text');
          final href = link?.attributes['href'] ?? '';

          final idMatch = RegExp(r'voddetail/([A-Za-z0-9]+)').firstMatch(href);
          final id = idMatch?.group(1) ?? '';

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
            categoryId: 0,
          );
        })
        .where((v) => v.id.isNotEmpty)
        .toList();
  }
}
