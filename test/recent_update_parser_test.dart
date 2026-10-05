import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/parser/recent_update_parser.dart';

/// RecentUpdateParser 解析契约测试
///
/// 覆盖首页（stui 主题）"最近更新"区块的真实结构：
/// - pannel head 含"最近更新"文本 → 解析其内部卡片
/// - 其它 pannel（每日热播等）的卡片不混入
/// - 卡片：封面 data-original + /v5/ 链接 + .pic-text 时长 + h4 标题
/// - 无"最近更新"区块 / 空输入 → 空列表（不抛异常）
void main() {
  group('RecentUpdateParser.parse', () {
    test('解析最近更新区块卡片（封面/时长/标题）', () {
      const html = '''
<html><body>
<div class="stui-pannel">
  <div class="stui-pannel__head"><h3>每日热播</h3></div>
  <div class="stui-pannel-bd"><ul class="stui-vodlist">
    <li class="stui-vodlist__item"><div class="stui-vodlist__box">
      <a href="/v5/999999-1-1.html" data-original="https://img.example.com/hot.jpg" title="热播影片">
        <span class="pic-text">12:00</span></a>
      <div class="stui-vodlist__detail"><h4><a href="/v5/999999-1-1.html">热播影片</a></h4></div>
    </div></li>
  </ul></div>
</div>
<div class="stui-pannel">
  <div class="stui-pannel__head"><h3>最近更新</h3></div>
  <div class="stui-pannel-bd"><ul class="stui-vodlist">
    <li class="stui-vodlist__item"><div class="stui-vodlist__box">
      <a href="/v5/272445-1-1.html" data-original="https://img.example.com/a.jpg" title="影片A">
        <span class="pic-text">50:31</span></a>
      <div class="stui-vodlist__detail"><h4><a href="/v5/272445-1-1.html">影片A</a></h4></div>
    </div></li>
    <li class="stui-vodlist__item"><div class="stui-vodlist__box">
      <a href="/v5/272439-1-1.html" data-original="https://img.example.com/b.jpg" title="影片B">
        <span class="pic-text">33:26</span></a>
      <div class="stui-vodlist__detail"><h4><a href="/v5/272439-1-1.html">影片B</a></h4></div>
    </div></li>
  </ul></div>
</div>
</body></html>
''';
      final videos = RecentUpdateParser().parse(html);
      // 只取"最近更新"区块（热播区块的 999999 不混入）
      expect(videos.length, 2);
      expect(videos.first.id, '272445-1-1');
      expect(videos.first.title, '影片A');
      expect(videos.first.coverUrl, 'https://img.example.com/a.jpg');
      expect(videos.first.duration, '50:31');
      expect(videos.first.categoryId, RecentUpdateParser.kNoCategoryId);
      expect(videos[1].id, '272439-1-1');
    });

    test('无最近更新区块返回空列表', () {
      const html = '''
<html><body>
<div class="stui-pannel">
  <div class="stui-pannel__head"><h3>每日热播</h3></div>
  <div class="stui-pannel-bd"><ul class="stui-vodlist"></ul></div>
</div>
</body></html>
''';
      expect(RecentUpdateParser().parse(html), isEmpty);
    });

    test('空 / 非法输入返回空列表（不抛异常）', () {
      expect(RecentUpdateParser().parse(''), isEmpty);
      expect(RecentUpdateParser().parse('not html <<<'), isEmpty);
    });
  });
}
