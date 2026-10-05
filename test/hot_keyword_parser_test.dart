import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/parser/hot_keyword_parser.dart';

/// HotKeywordParser 单测 — 热门词条解析契约
///
/// fixture 采用站点真实 header 结构（2026-09 实测）：
/// `<a href="/vodsearch/{词条URL编码}-------------.html">词条</a>`（13 连字符）
void main() {
  group('HotKeywordParser.parse', () {
    test('解析正常 header 词条（URL 解码 + 去重保序）', () {
      const html = '''
        <html><body><header>
          <a href="/vodsearch/%E6%97%A5%E6%9C%AC-------------.html">日本</a>
          <a href="/vodsearch/swag-------------.html">swag</a>
          <a href="/vodsearch/%E5%9B%BD%E4%BA%A7-------------.html">国产</a>
          <a href="/vodsearch/swag-------------.html">swag重复</a>
        </header><div>正文</div></body></html>
      ''';
      final kws = HotKeywordParser.parse(html);
      expect(kws, ['日本', 'swag', '国产']);
    });

    test('忽略非快捷搜索链接与干扰项', () {
      const html = '''
        <a href="/vodtype/1.html">分类</a>
        <a href="/v5/8802-1-1.html">影片</a>
        <a href="/vodsearch/%E6%97%A5%E6%9C%AC----------2---.html">分页搜索</a>
        <a href="/vodsearch/-------------.html">空词条</a>
        <a href="https://example.com/vodsearch/x-------------.html">外域</a>
      ''';
      final kws = HotKeywordParser.parse(html);
      expect(kws, isEmpty);
    });

    test('超过 maxCount 截断', () {
      final links = List.generate(
        25,
        (i) => '<a href="/vodsearch/k$i-------------.html">k$i</a>',
      ).join();
      final kws = HotKeywordParser.parse(links);
      expect(kws.length, 20);
      expect(kws.first, 'k0');
      expect(kws.last, 'k19');
    });

    test('空 HTML / 无链接返回空列表', () {
      expect(HotKeywordParser.parse(''), isEmpty);
      expect(HotKeywordParser.parse('<html><body></body></html>'), isEmpty);
    });

    test('非法 URL 编码序列跳过且不中断', () {
      const html = '''
        <a href="/vodsearch/%E6%97%A-------------.html">坏的</a>
        <a href="/vodsearch/%E6%97%A5%E6%9C%AC-------------.html">日本</a>
      ''';
      final kws = HotKeywordParser.parse(html);
      expect(kws, ['日本']);
    });
  });
}
