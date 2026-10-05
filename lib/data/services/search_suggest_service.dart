import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/utils/logger.dart';

/// 搜索联想项
///
/// 来自站点 suggest JSON 接口的单条记录：
/// `{"id": "271207", "name": "标题", "en": "拼音", "pic": "https://..."}`
///
/// [videoId] 已按站点单集结构补全为复合 ID `{aid}-1-1`，
/// 可直接用于跳转详情页路由。
class SearchSuggestion {
  /// 复合视频 ID（`aid-sid-nid`，如 `271207-1-1`）
  final String videoId;

  /// 影片标题
  final String title;

  /// 封面图 URL
  final String coverUrl;

  const SearchSuggestion({
    required this.videoId,
    required this.title,
    required this.coverUrl,
  });

  /// 从 suggest 接口单条 JSON 构造
  ///
  /// - `id` 为纯数字 aid，补全 `-1-1`（站点单集：sid=1、nid=1 固定）
  /// - `name`/`pic` 缺失时降级为空串（UI 层兜底展示）
  factory SearchSuggestion.fromMap(Map<String, dynamic> map) {
    final aid = (map['id'] ?? '').toString().trim();
    return SearchSuggestion(
      videoId: '$aid-1-1',
      title: (map['name'] ?? '').toString().trim(),
      coverUrl: (map['pic'] ?? '').toString().trim(),
    );
  }
}

/// 搜索联想服务
///
/// 封装 macCMS 标准 suggest 接口（`/index.php/ajax/suggest?mid=1&wd=xx`）：
/// - 输入关键词实时联想影片（标题 + 封面）
/// - 最多 20 条（接口不支持翻页）
/// - 任何异常返回空列表（联想是辅助体验，不向上抛错）
///
/// 使用场景：搜索页输入过程中实时下拉联想，点击联想项直达详情页；
/// 输入演员名片段可联想其参演作品，实现"演员作品快速到达"。
class SearchSuggestService {
  SearchSuggestService._();

  /// 请求搜索联想
  ///
  /// [keyword] 输入中的关键词（≥1 字符才请求）
  static Future<List<SearchSuggestion>> suggest(String keyword) async {
    final text = keyword.trim();
    if (text.isEmpty) return const [];

    try {
      final data = await ApiService().fetchSearchSuggest(text);
      final code = data['code'];
      final list = data['list'];
      // code != 1 为业务失败（如参数异常）；list 非数组视为空
      if (code != 1 || list is! List) return const [];

      return list
          .whereType<Map>()
          .map((e) => SearchSuggestion.fromMap(Map<String, dynamic>.from(e)))
          .where((s) => s.videoId != '-1-1' && s.title.isNotEmpty)
          .toList();
    } catch (e, st) {
      appLogger.w('搜索联想请求失败(keyword=$text)', error: e, stackTrace: st);
      return const [];
    }
  }
}
