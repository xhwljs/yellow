import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:yellow_depot/core/error/exceptions.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/models/video_detail.dart';

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

      // 播放量 / 收藏数 / 发布时间（尝试从详情页 HTML 提取）
      // 站点结构未确认，用多 selector 兜底；提取不到时返回 0/0/''
      // 由 controller 经 cacheVideo 合并策略从列表页缓存补全
      final playCount = _extractPlayCount(doc);
      final likeCount = _extractLikeCount(doc);
      final updateTime = _extractUpdateTime(doc);

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
          updateTime: updateTime,
          playCount: playCount,
          likeCount: likeCount,
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
  /// 详情页本身**没有独立大封面**（实测结构）：
  /// - `.stui-content__thumb` 不存在
  /// - 相关推荐 `.stui-vodlist__box` 里第一个 a 标签是广告，其 data-original
  ///   是广告图（gif）—— 不能用作视频封面
  ///
  /// 因此这里**直接返回空**，由上层 VideoDetailController 用列表页
  /// 传入的 coverUrl 覆盖 detail.video.coverUrl。
  static String _extractCoverUrl(dom.Document doc) {
    // 预留：未来若站点恢复 .stui-content__thumb img 结构，从这里取
    final thumbImg = doc.querySelector('.stui-content__thumb img');
    final cover =
        thumbImg?.attributes['data-original'] ?? thumbImg?.attributes['src'];
    if (cover != null && cover.isNotEmpty) return cover;
    return '';
  }

  /// 提取播放量（fa-eye 图标旁边的数字）
  ///
  /// macCMS V10 + stui 主题常见结构：
  /// `<span><i class="fa fa-eye"></i> 61753</span>`
  /// 或 `<li><i class="fa fa-eye"></i> 61753</li>`
  ///
  /// 提取失败返回 0，由 controller 经 cacheVideo 从列表页缓存补全。
  static int _extractPlayCount(dom.Document doc) {
    return _extractFaIconNumber(doc, 'fa-eye');
  }

  /// 提取收藏数（fa-heart 图标旁边的数字）
  ///
  /// 同 [_extractPlayCount]，提取失败返回 0。
  static int _extractLikeCount(dom.Document doc) {
    return _extractFaIconNumber(doc, 'fa-heart');
  }

  /// 通用提取：在指定 fa-{iconClass} 图标所在的 span/li/p 元素中提取数字
  ///
  /// 搜索范围（优先级）：
  /// 1. `.stui-content__detail`（详情页元信息区，macCMS 标准结构）
  /// 2. `.stui-content`（更宽范围）
  /// 3. `.module-info-content`（其他 macCMS 主题）
  /// 4. `body`（兜底全文档搜索）
  ///
  /// 找到图标后取其父元素的 text，正则匹配数字（支持千分位逗号）。
  static int _extractFaIconNumber(dom.Document doc, String faClass) {
    final scopes = <dom.Element?>[
      doc.querySelector('.stui-content__detail'),
      doc.querySelector('.stui-content'),
      doc.querySelector('.module-info-content'),
      doc.body,
    ].whereType<dom.Element>().toList();

    for (final scope in scopes) {
      final icons = scope.querySelectorAll('i.$faClass');
      for (final icon in icons) {
        final parent = icon.parent;
        if (parent == null) continue;
        final text = parent.text;
        final match = RegExp(r'(\d[\d,]*)').firstMatch(text);
        if (match != null) {
          final num = int.tryParse(match.group(1)!.replaceAll(',', ''));
          if (num != null && num > 0) return num;
        }
      }
    }
    return 0;
  }

  /// 提取发布时间（YYYY-MM-DD 或 MM-DD）
  ///
  /// 搜索范围同 [_extractFaIconNumber]，额外支持：
  /// - 优先匹配带"更新时间/发布时间/时间"标签的元素
  /// - 降级匹配整个 scope 文本中的日期模式
  ///
  /// macCMS 常见结构：
  /// `<span>更新时间：2024-01-01</span>`
  /// 或 `<li>2024-01-01</li>`
  static String _extractUpdateTime(dom.Document doc) {
    final scopes = <dom.Element?>[
      doc.querySelector('.stui-content__detail'),
      doc.querySelector('.stui-content'),
      doc.querySelector('.module-info-content'),
      doc.body,
    ].whereType<dom.Element>().toList();

    const datePattern = r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}-\d{1,2})';
    const labeledPattern =
        r'(?:更新时间|发布时间|时间|日期)\s*[:：]?\s*(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}-\d{1,2})';

    for (final scope in scopes) {
      // 1) 优先找带"更新/发布时间"标签的元素
      final labelEls = scope.querySelectorAll('span, li, p, div, em');
      for (final el in labelEls) {
        final text = el.text;
        final labeledMatch = RegExp(labeledPattern).firstMatch(text);
        if (labeledMatch != null) {
          return labeledMatch.group(1)!;
        }
      }
      // 2) 降级：scope 全文日期匹配
      final match = RegExp(datePattern).firstMatch(scope.text);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return '';
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
  ///
  /// 2026-08-02 优化：根据真实播放页 HTML 源码，相关推荐项的
  /// `.stui-vodlist__detail p.sub` 实际包含播放量（fa-eye）、
  /// 收藏数（fa-heart）和更新时间（MM-DD）。之前硬编码为 0/0/''
  /// 是基于错误假设，现在复用列表页 parser 同款解析逻辑提取真实数据，
  /// 让相关推荐卡片能显示真实播放量 / 收藏数 / 更新时间。
  ///
  /// 真实 HTML 结构（来自 hsck.tv 播放页）：
  /// ```html
  /// <div class="stui-vodlist__box">
  ///   <a class="stui-vodlist__thumb" href="/v5/8802-1-1.html"
  ///      data-original="https://...jpg">
  ///     <span class="pic-text text-right">31:05</span>
  ///   </a>
  ///   <div class="stui-vodlist__detail">
  ///     <h4 class="title"><a href="/v5/8802-1-1.html">标题</a></h4>
  ///     <p class="sub">
  ///       <span class="number pull-right"><i class="fa fa-heart"></i> 946 </span>
  ///       <span class="pull-right"><i class="fa fa-eye"></i> 1817286 </span>
  ///       06-11
  ///     </p>
  ///   </div>
  /// </div>
  /// ```
  static List<Video> _parseRelatedVideos(dom.Document doc) {
    final items = doc.querySelectorAll('.stui-vodlist__box');
    return items
        .map((element) {
          // 优先取指向 /v5/ 的 a 标签（真实视频），降级到旧路径 /voddetail/
          // 外站广告的 href 是 https://xxx.com，会被 /v5/ 过滤掉
          final link = element.querySelector('a[href*="/v5/"]') ??
              element.querySelector('a[href*="/voddetail/"]');
          if (link == null) return null;

          final href = link.attributes['href'] ?? '';
          final id = _extractVideoId(href);
          if (id.isEmpty) {
            return null;
          }

          // 封面：优先 a[data-original]，降级 img[data-original] / img[src]
          final coverUrl = link.attributes['data-original'] ??
              element.querySelector('img')?.attributes['data-original'] ??
              element.querySelector('img')?.attributes['src'] ??
              '';

          // 标题：优先 .stui-vodlist__detail h4 a，降级 a[title] / a.text
          final detailEl = element.querySelector('.stui-vodlist__detail');
          final title = detailEl?.querySelector('h4 a')?.text.trim() ??
              link.attributes['title']?.trim() ??
              link.text.trim();

          // 时长在 a 内的 .pic-text
          final picText = link.querySelector('.pic-text') ??
              element.querySelector('.pic-text');
          final duration = picText?.text.trim() ?? '';

          // 播放量 / 收藏数 / 更新时间（在 .stui-vodlist__detail .sub 内）
          // 复用列表页 parser 同款逻辑，按 fa 图标 class 区分字段
          // 注意：不能按数字出现顺序解析（HTML 中 heart 在 eye 前，会搞反）
          final subEl = detailEl?.querySelector('.sub');
          final playCount = _extractNumberFromSub(subEl, 'fa-eye');
          final likeCount = _extractNumberFromSub(subEl, 'fa-heart');
          final updateTime = _extractUpdateTimeFromSub(subEl);

          return Video(
            id: id,
            title: title,
            coverUrl: coverUrl,
            duration: duration,
            updateTime: updateTime,
            playCount: playCount,
            likeCount: likeCount,
            categoryId: 0,
          );
        })
        .whereType<Video>()
        .toList();
  }

  /// 从 `.sub` 元素中提取带指定 fa 图标的数字
  ///
  /// HTML 结构：`<span class="pull-right"><i class="fa fa-eye"></i> 61753 </span>`
  /// → 提取 61753
  ///
  /// 必须按 fa 图标 class 区分字段（fa-eye=播放量，fa-heart=收藏数），
  /// 不能按数字出现顺序解析，因为 HTML 中 heart span 在 eye span 之前。
  static int _extractNumberFromSub(dom.Element? subEl, String faClass) {
    if (subEl == null) return 0;
    try {
      // 匹配带指定 fa 图标的 span（class 含 pull-right 或 number）
      final spans = subEl.querySelectorAll('span.pull-right, span.number');
      for (final span in spans) {
        final icon = span.querySelector('i.fa.$faClass');
        if (icon != null) {
          // 去掉所有非数字字符（含 &nbsp;、空格、逗号）
          final text = span.text.replaceAll(RegExp(r'[^\d]'), '');
          return int.tryParse(text) ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// 从 `.sub` 元素提取更新时间（MM-DD 或 YYYY-MM-DD）
  ///
  /// HTML 结构：`<p class="sub">...<span>...</span>06-11</p>`
  /// `.sub` 尾部文本通常是 MM-DD 格式的更新时间。
  static String _extractUpdateTimeFromSub(dom.Element? subEl) {
    if (subEl == null) return '';
    try {
      final text = subEl.text;
      // 匹配 YYYY-MM-DD 或 MM-DD
      final match =
          RegExp(r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}-\d{1,2})').firstMatch(text);
      return match?.group(1) ?? '';
    } catch (_) {}
    return '';
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
