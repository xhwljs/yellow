import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/parser/rss_parser.dart';

/// RssParser 解析契约测试
///
/// 覆盖站点 /rss.xml 的真实形态（2026-09 实测样本结构）：
/// - 标准 item（title + 坏链 link + pubDate）→ 正确提取并转 Video
/// - 坏链 link 的双前缀形态（http://http://外域/voddetail/{aid}.html）
/// - 相对路径 link 形态（/voddetail/{aid}.html）
/// - 缺 title / 缺 aid 的 item → 跳过
/// - pubDate 解析 + 相对时间
/// - XML 实体解码（&amp; 等）
void main() {
  group('RssParser.parse', () {
    test('解析标准 item：提取 aid 构造复合 videoId + 相对时间', () {
      final xml = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel>
<item>
  <title>示例标题A</title>
  <link>http://http://hsck.tv/voddetail/272445.html</link>
  <pubDate>2026-10-05 07:46:31</pubDate>
</item>
</channel></rss>
''';
      final videos = RssParser.parse(xml);
      expect(videos.length, 1);
      final v = videos.first;
      // 单集站点结构：aid-1-1
      expect(v.id, '272445-1-1');
      expect(v.title, '示例标题A');
      // RSS 不提供封面/时长
      expect(v.coverUrl, isEmpty);
      expect(v.duration, isEmpty);
      // pubDate 有效（今天发布的显示相对时间，具体文案随时间变化但非空）
      expect(v.updateTime, isNotEmpty);
    });

    test('坏链双前缀与相对路径形态都能提取 aid', () {
      final xml = '''
<rss><channel>
<item><title>A</title><link>http://http://hsck.tv/voddetail/111.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
<item><title>B</title><link>/voddetail/222.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
<item><title>C</title><link>https://example.com/voddetail/333.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
</channel></rss>
''';
      final videos = RssParser.parse(xml);
      expect(videos.map((v) => v.id).toList(),
          ['111-1-1', '222-1-1', '333-1-1']);
    });

    test('缺 title 或无法提取 aid 的 item 跳过', () {
      final xml = '''
<rss><channel>
<item><link>/voddetail/111.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
<item><title>无aid</title><link>https://example.com/other/999.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
<item><title>正常</title><link>/voddetail/222.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
</channel></rss>
''';
      final videos = RssParser.parse(xml);
      expect(videos.length, 1);
      expect(videos.first.id, '222-1-1');
    });

    test('空 / 非法输入返回空列表', () {
      expect(RssParser.parse(''), isEmpty);
      expect(RssParser.parse('<html><body>not rss</body></html>'), isEmpty);
    });

    test('XML 实体解码（&amp; 等）', () {
      final xml = '''
<rss><channel>
<item><title>A &amp; B</title><link>/voddetail/111.html</link><pubDate>2026-10-05 07:46:31</pubDate></item>
</channel></rss>
''';
      final videos = RssParser.parse(xml);
      expect(videos.first.title, 'A & B');
    });
  });

  group('RssParser 相对时间', () {
    test('过旧时间显示日期（跨年带年份）', () {
      final xml =
          '<rss><channel><item><title>T</title><link>/voddetail/1.html</link>'
          '<pubDate>2024-01-01 00:00:00</pubDate></item></channel></rss>';
      final v = RssParser.parse(xml).first;
      expect(v.updateTime, startsWith('2024-'));
    });
  });
}
