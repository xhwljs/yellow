import 'package:html/parser.dart' as html_parser;
import 'package:yellow_depot/core/parser/video_list_parser.dart';
import 'package:yellow_depot/data/models/video.dart';

/// 首页"最近更新"区块解析器
///
/// 定位首页（stui 主题）中标题含"最近更新"的 pannel，
/// 解析其内部 `.stui-vodlist__box` 卡片（封面 `data-original` +
/// 时长 `.pic-text` + 标题），卡片解析逻辑复用 [VideoListParser]。
///
/// 与站点 `/rss.xml` 同源（最新上架流，实测 aid 序列完全一致），
/// 用于为 RSS 条目补全封面 / 时长 / 干净标题
/// （RSS 仅提供带时长尾巴的标题，不提供图片字段，见 [RssParser]）。
///
/// 区块结构（2026-10 实测）：
/// ```html
/// <div class="stui-pannel">
///   <div class="stui-pannel__head"><h3>最近更新 ...</h3></div>
///   <div class="stui-pannel-bd">
///     <ul class="stui-vodlist">
///       <li class="stui-vodlist__item"><div class="stui-vodlist__box">...</div></li>
///       ...
///     </ul>
///   </div>
/// </div>
/// ```
class RecentUpdateParser {
  /// 无分类标识（与 RSS 数据源一致：跨分类，无 categoryId）
  static const int kNoCategoryId = -1;

  /// 解析首页 HTML，返回"最近更新"区块的视频列表（约 40 条）
  ///
  /// 未找到区块 / 解析异常 → 返回空列表（由调用方降级处理），
  /// 不抛异常：封面补全是增强能力，不应阻断最新流加载。
  List<Video> parse(String html) {
    if (html.isEmpty) return const [];

    try {
      final doc = html_parser.parse(html);
      // 定位"最近更新" pannel（pannel head 文本匹配）
      for (final head in doc.querySelectorAll('.stui-pannel__head')) {
        if (!head.text.contains('最近更新')) continue;
        final pannel = head.parent;
        final boxes = pannel?.querySelectorAll('.stui-vodlist__box');
        if (boxes == null || boxes.isEmpty) continue;
        return VideoListParser(categoryId: kNoCategoryId)
            .parseElements(boxes);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
