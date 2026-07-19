import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/models/video_detail.dart';

/// 视频详情解析器
///
/// 站点当前结构（2026）：
/// - 详情页 URL：`/v5/{aid}-{sid}-{nid}.html`
/// - 标题：`.stui-pannel__head h3.title`（多个 pannel__head，第一个是 "目录"，
///   第二个才是视频标题）
/// - 封面：详情页本身可能无独立封面，从相关推荐里取（或留空交给上层）
/// - AID/ASID/ANID/AK：在 `<script>` 内的 `var AID='xxx', ASID='x', ANID='x', AK='xxx'`
/// - 相关推荐：`.stui-vodlist__box` 里 href 含 `/v5/` 的（过滤广告）
class VideoDetailParser {
  VideoDetailParser._();

  /// 从视频详情页 HTML 解析 VideoDetail
  ///
  /// [videoId] 为复合 ID `aid-sid-nid`（来自列表页）或单 ID `aid`。
  static VideoDetail parse(String html, String videoId) {
    if (html.isEmpty) {
      throw const ParseException('详情页 HTML 为空');
    }

    try {
      final doc = html_parser.parse(html);

      // 标题：跳过 "目录" 标签，取第二个 .stui-pannel__head 内的 h3.title
      final title = _extractTitle(doc) ?? videoId;

      // 简介（当前站点无简介结构，留空）
      final description = _extractDescription(doc);

      // 时长（如有）
      final duration = _extractDuration(doc);

      // 封面（取相关推荐第一张图作为占位；上层 detail.video.coverUrl 来自列表页）
      final coverUrl = _extractCoverUrl(doc);

      // AK Token
      final token = _extractToken(doc);

      // AID/ASID/ANID 从 script 中提取
      final aid =
          _extractScriptVar(doc, 'AID') ?? _parseAidFromVideoId(videoId);
      final sid = _extractScriptVar(doc, 'ASID') ??
          _parseSidFromVideoId(videoId) ??
          '1';
      final nid = _extractScriptVar(doc, 'ANID') ??
          _parseNidFromVideoId(videoId) ??
          '1';

      // 相关推荐（过滤广告）
      final relatedVideos = _parseRelatedVideos(doc);

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
        // 同时存 aid 用于 POST（解密模块会从 detail 取 aid/sid/nid）
        aid: aid,
      );
    } catch (e) {
      if (e is ParseException) rethrow;
      throw ParseException(
        '视频详情解析失败',
        selector: '.stui-pannel__head h3.title',
        cause: e,
      );
    }
  }

  /// 提取标题
  ///
  /// 优先级：
  /// 1. `.stui-pannel__head h3.title`（多个，取文本长度 > 5 的第一个）
  /// 2. `h1.title`
  /// 3. `<title>` 标签内容（去掉站点后缀）
  static String? _extractTitle(dom.Document doc) {
    // 优先 .stui-pannel__head h3.title
    final heads = doc.querySelectorAll(
      '.stui-pannel__head h3.title, .stui-pannel__head .title',
    );
    for (final h in heads) {
      final text = h.text.trim();
      if (text.isNotEmpty && text.length > 5 && text != '目录') {
        return text;
      }
    }
    // 降级 h1.title
    final h1 = doc.querySelector('h1.title');
    if (h1 != null) {
      final t = h1.text.trim();
      if (t.isNotEmpty) return t;
    }
    // 降级 <title>
    final titleTag = doc.querySelector('title');
    if (titleTag != null) {
      final t = titleTag.text.trim();
      // 去掉 " - 站点名" 后缀
      final idx = t.lastIndexOf(' - ');
      return idx > 0 ? t.substring(0, idx) : t;
    }
    return null;
  }

  /// 提取简介
  ///
  /// 当前站点详情页无独立简介结构，返回空字符串。
  static String _extractDescription(dom.Document doc) {
    final descEl = doc.querySelector(
      '.stui-content__detail .desc, .stui-pannel__desc, .detail-sketch, .content_detail .detail-sketch',
    );
    return descEl?.text.trim() ?? '';
  }

  /// 提取时长
  static String _extractDuration(dom.Document doc) {
    final el = doc.querySelector('.stui-content__detail .pic-text, .pic-text');
    return el?.text.trim() ?? '';
  }

  /// 提取封面
  ///
  /// 当前详情页无独立大图封面，从相关推荐第一张 a[data-original] 取占位。
  /// 上层应优先使用列表页传入的 coverUrl。
  static String _extractCoverUrl(dom.Document doc) {
    // 详情页有时有 .stui-content__thumb img
    final thumbImg = doc.querySelector('.stui-content__thumb img');
    final cover =
        thumbImg?.attributes['data-original'] ?? thumbImg?.attributes['src'];
    if (cover != null && cover.isNotEmpty) return cover;

    // 降级：相关推荐第一张 a[data-original]
    final a = doc.querySelector('a.stui-vodlist__thumb[data-original]');
    return a?.attributes['data-original'] ?? '';
  }

  /// 从 `<script>` 中提取 `AK='xxx'` 的 token
  ///
  /// 兼容：`AK='xxx'` 与 `AK="xxx"`，以及 `var AK='xxx'`。
  static String? _extractToken(dom.Document doc) {
    final scripts = doc.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final match = RegExp(r"AK\s*=\s*'([^']+)'").firstMatch(text);
      if (match != null) return match.group(1);
      final matchDouble = RegExp(r'AK\s*=\s*"([^"]+)"').firstMatch(text);
      if (matchDouble != null) return matchDouble.group(1);
    }
    return null;
  }

  /// 从 `<script>` 中提取变量值（如 AID、ASID、ANID）
  ///
  /// 匹配 `var AID='xxx'` 或 `AID='xxx'`（单/双引号）。
  static String? _extractScriptVar(dom.Document doc, String name) {
    final scripts = doc.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final single = RegExp("$name\\s*=\\s*'([^']+)'").firstMatch(text);
      if (single != null) return single.group(1);
      final double = RegExp('$name\\s*=\\s*"([^"]+)"').firstMatch(text);
      if (double != null) return double.group(1);
    }
    return null;
  }

  /// 从复合 videoId `aid-sid-nid` 解析 aid
  static String? _parseAidFromVideoId(String videoId) {
    if (videoId.contains('-')) {
      return videoId.split('-').firstOrNull;
    }
    return videoId.isEmpty ? null : videoId;
  }

  /// 从复合 videoId `aid-sid-nid` 解析 sid
  static String? _parseSidFromVideoId(String videoId) {
    final parts = videoId.split('-');
    if (parts.length >= 2) return parts[1];
    return null;
  }

  /// 从复合 videoId `aid-sid-nid` 解析 nid
  static String? _parseNidFromVideoId(String videoId) {
    final parts = videoId.split('-');
    if (parts.length >= 3) return parts[2];
    return null;
  }

  /// 解析相关推荐视频列表
  ///
  /// 只取 href 含 `/v5/` 的（过滤广告）。
  static List<Video> _parseRelatedVideos(dom.Document doc) {
    final items = doc.querySelectorAll('.stui-vodlist__box');
    return items
        .map((element) {
          // 优先取指向 /v5/ 的 a 标签，降级到旧路径 /voddetail/
          final link = element.querySelector('a[href*="/v5/"]') ??
              element.querySelector('a[href*="/voddetail/"]');
          if (link == null) return null;

          final href = link.attributes['href'] ?? '';
          final id = _extractVideoId(href);
          if (id.isEmpty) {
            return null;
          }

          final coverUrl = link.attributes['data-original'] ??
              element.querySelector('img')?.attributes['data-original'] ??
              element.querySelector('img')?.attributes['src'] ??
              '';

          final detailEl = element.querySelector('.stui-vodlist__detail');
          final title = detailEl?.querySelector('h4 a')?.text.trim() ??
              link.attributes['title']?.trim() ??
              link.text.trim();

          final picText = link.querySelector('.pic-text') ??
              element.querySelector('.pic-text');
          final duration = picText?.text.trim() ?? '';

          return Video(
            id: id,
            title: title,
            coverUrl: coverUrl,
            duration: duration,
            updateTime: '',
            playCount: 0,
            likeCount: 0,
            categoryId: 0,
          );
        })
        .whereType<Video>()
        .toList();
  }

  /// 提取 videoId（支持 `/v5/{aid}-{sid}-{nid}.html` 与旧 `/voddetail/{id}.html`）
  static String _extractVideoId(String href) {
    final v5Match = RegExp(r'/v5/([A-Za-z0-9_-]+)\.html').firstMatch(href);
    if (v5Match != null) return v5Match.group(1) ?? '';
    final vodMatch = RegExp(r'voddetail/([A-Za-z0-9]+)').firstMatch(href);
    if (vodMatch != null) return vodMatch.group(1) ?? '';
    return '';
  }
}
