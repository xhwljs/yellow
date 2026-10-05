import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/parser/hot_keyword_parser.dart';
import 'package:yellow_depot/core/utils/logger.dart';

/// 热门搜索词条服务
///
/// 数据链路：
/// `/topic.html`（[ApiService.fetchTopicHtml]）→
/// [HotKeywordParser] 解析 header 快捷搜索词条 → SharedPreferences 缓存。
///
/// 缓存策略：
/// - TTL 内（[AppConstants.hotKeywordsCacheTtl]，12 小时）直接读缓存，不发请求
/// - 过期则拉取刷新；拉取失败时回退旧缓存（词条由站方运营配置，变更频率低，
///   旧数据仍有参考价值）
/// - 首次无缓存且拉取失败 → 返回空列表（搜索页隐藏热门搜索区，不报错打扰）
///
/// 使用方式：搜索页初始化时调用 [load]。
class HotKeywordService {
  HotKeywordService._();

  /// 加载热门搜索词条
  ///
  /// [forceRefresh] 为 true 时忽略 TTL 强制刷新（预留给下拉刷新场景）。
  static Future<List<String>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList(AppConstants.keyHotKeywordsCache) ?? [];
    final cachedTs =
        prefs.getInt(AppConstants.keyHotKeywordsCacheTs) ?? 0;
    final isFresh = DateTime.now().millisecondsSinceEpoch - cachedTs <
        AppConstants.hotKeywordsCacheTtl.inMilliseconds;

    if (!forceRefresh && cached.isNotEmpty && isFresh) {
      return cached;
    }

    // 缓存缺失或过期 → 拉取刷新
    try {
      final html = await ApiService().fetchTopicHtml();
      final keywords = HotKeywordParser.parse(html);
      if (keywords.isEmpty) {
        // 解析结果为空（页面结构变化或被拦截）→ 回退缓存
        appLogger.w('HotKeywordParser 解析结果为空，回退缓存(${cached.length}条)');
        return cached;
      }
      await prefs.setStringList(AppConstants.keyHotKeywordsCache, keywords);
      await prefs.setInt(AppConstants.keyHotKeywordsCacheTs,
          DateTime.now().millisecondsSinceEpoch);
      return keywords;
    } catch (e, st) {
      appLogger.w('热门词条拉取失败，回退缓存', error: e, stackTrace: st);
      return cached;
    }
  }
}
