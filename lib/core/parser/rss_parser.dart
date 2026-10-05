import 'package:yellow_depot/data/models/video.dart';

/// RSS 解析器（N2：首页"最新上架"数据源）
///
/// 解析站点 `/rss.xml`（全站最新上架流，30 条）：
/// ```xml
/// <item>
///   <title>标题</title>
///   <link>http://http://hsck.tv/voddetail/272445.html</link>
///   <pubDate>2026-10-05 07:46:31</pubDate>
/// </item>
/// ```
///
/// 注意：
/// - item 的 link 是站方配置错误的双前缀外域地址（不可直接访问），
///   需从中提取 aid 再构造本站详情页 videoId = `{aid}-1-1`
///   （站点为单集结构：sid=1 / nid=1 固定）
/// - pubDate 形如 `2026-10-05 07:46:31`，转为相对时间（"3小时前"）
///   存入 [Video.updateTime]，由卡片元信息行展示
/// - XML 无 CDATA 转义风险（title 为纯文本），用正则解析足够；
///   解析失败的 item 直接跳过，不抛异常
class RssParser {
  RssParser._();

  /// 解析 RSS XML 为最新视频列表
  ///
  /// 返回按发布时间倒序（RSS 本身有序，保持原顺序）的 [Video] 列表：
  /// - id：`{aid}-1-1`（可直接进入详情页）
  /// - updateTime：相对时间（"3小时前" / "2天前"）
  /// - coverUrl / duration 等字段为空（RSS 不提供，详情页补全）
  static List<Video> parse(String xml) {
    final items =
        RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml);
    final videos = <Video>[];
    for (final m in items) {
      final block = m.group(1) ?? '';
      final title = _tag(block, 'title');
      final link = _tag(block, 'link');
      final pubDate = _tag(block, 'pubDate');
      if (title.isEmpty) continue;

      // 从（可能是坏的）link 中提取影片 aid
      final aid = _extractAid(link);
      if (aid == null) continue;

      final publishedAt = _parseDate(pubDate);
      videos.add(Video(
        id: '$aid-1-1',
        title: _decodeXmlEntities(title),
        coverUrl: '',
        duration: '',
        updateTime: _relativeTime(publishedAt),
        playCount: 0,
        likeCount: 0,
        categoryId: -1, // RSS 跨分类，无分类信息
      ));
    }
    return videos;
  }

  /// 提取首个 XML 标签的文本内容（title/link/pubDate）
  static String _tag(String block, String tag) {
    final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(block);
    return (m?.group(1) ?? '').trim();
  }

  /// 从 RSS link 提取影片 aid
  ///
  /// 兼容形态（实测）：
  /// - `http://http://hsck.tv/voddetail/272445.html`（双前缀坏链）
  /// - `/voddetail/272445.html`（相对路径）
  /// - `https://任意域名/voddetail/272445.html`
  static String? _extractAid(String link) {
    final m = RegExp(r'/voddetail/(\d+)\.html').firstMatch(link);
    return m?.group(1);
  }

  /// 解析 `yyyy-MM-dd HH:mm:ss` 格式时间（站点 RSS pubDate 格式）
  static DateTime? _parseDate(String s) {
    final m =
        RegExp(r'(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
            .firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }

  /// 相对时间描述（"34分钟前" / "3小时前" / "2天前" / "10-01"）
  ///
  /// 同一天内显示分钟/小时；7 天内显示天数；更早显示 `MM-dd`（跨年带年份）。
  /// 解析失败时返回空字符串（卡片自动隐藏该行）。
  static String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.isNegative) return '刚刚';
    final minutes = diff.inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    final hours = diff.inHours;
    if (hours < 24) return '$hours小时前';
    final days = diff.inDays;
    if (days < 7) return '$days天前';
    final now = DateTime.now();
    final sameYear = time.year == now.year;
    final mm = time.month.toString().padLeft(2, '0');
    final dd = time.day.toString().padLeft(2, '0');
    return sameYear ? '$mm-$dd' : '${time.year}-$mm-$dd';
  }

  /// 解码常见 XML 实体（RSS title 可能含 &amp; 等）
  static String _decodeXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
