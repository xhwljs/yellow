import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/parser/video_detail_parser.dart';

/// 详情页元数据解析契约测试（数据源：站点真实 HTML 片段，
/// 2026-09 实测 `.stui-player__foot` 服务端直出结构）
void main() {
  // 站点真实结构节选（值已脱敏为占位形态，结构不变）
  const footHtml = '''
<div class="stui-player__foot">
  <span class="pull-right"><span class="text-red">7173</span>次播放</span>
  时间：2026-10-05 07:10:31
  <div class="mac_digg" style="float:left">
    <span class="click-ding-gw"><a class="digg_link" data-id="1">
      <em class="digg_num">&nbsp;7</em></a></span>
  </div>
</div>
''';

  test('播放量：从 .stui-player__foot .text-red 提取（非 JS 填充的 hide span）', () {
    final d = VideoDetailParser.parse(
      '<html><body>$footHtml</body></html>',
      '272445-1-1',
    );
    expect(d.video.playCount, 7173);
  });

  test('更新时间：提取"时间：YYYY-MM-DD HH:mm"并截断到分钟', () {
    final d = VideoDetailParser.parse(
      '<html><body>$footHtml</body></html>',
      '272445-1-1',
    );
    expect(d.video.updateTime, '2026-10-05 07:10');
  });

  test('无 player__foot 时回退旧结构且不崩溃（返回默认值）', () {
    final d = VideoDetailParser.parse(
      '<html><body><div class="stui-content__detail">'
      '<span>更新时间：2026-01-02</span></div></body></html>',
      '272445-1-1',
    );
    expect(d.video.updateTime, '2026-01-02');
    expect(d.video.playCount, 0);
  });
}
