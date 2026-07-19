import 'package:shared_preferences/shared_preferences.dart';
import 'package:videohub/core/constants/app_constants.dart';

/// 搜索历史本地存储服务
///
/// 使用 SharedPreferences 持久化搜索关键字列表。
///
/// 规则：
/// - 同一关键字再次搜索时上移到列表头部（最近优先）
/// - 自动去重
/// - 最多保留 [AppConstants.searchHistoryMax] 条，超出按时间倒序裁剪
/// - 关键字 trim 后为空不保存
///
/// 使用方式：
/// - 搜索发起后调用 [add]
/// - 搜索页进入时调用 [load]
/// - 单条删除调用 [remove]
/// - 清空调用 [clear]
class SearchHistoryService {
  SearchHistoryService._();

  /// 加载全部搜索历史（按最近优先排序）
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.keySearchHistory) ?? [];
  }

  /// 添加一条搜索关键字
  ///
  /// 行为：
  /// - trim 后为空 → 不保存，返回当前列表
  /// - 已存在 → 移到列表头部（最近优先）
  /// - 不存在 → 插入头部
  /// - 超过 [AppConstants.searchHistoryMax] → 裁剪尾部
  ///
  /// 返回保存后的最新列表。
  static Future<List<String>> add(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return load();

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(AppConstants.keySearchHistory) ?? [];

    // 去重：先移除已存在的同名条目
    list.remove(trimmed);
    // 插入头部
    list.insert(0, trimmed);

    // 裁剪
    if (list.length > AppConstants.searchHistoryMax) {
      list.removeRange(
        AppConstants.searchHistoryMax,
        list.length,
      );
    }

    await prefs.setStringList(AppConstants.keySearchHistory, list);
    return list;
  }

  /// 删除单条搜索历史
  ///
  /// 返回删除后的最新列表。
  static Future<List<String>> remove(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(AppConstants.keySearchHistory) ?? [];
    list.remove(keyword);
    await prefs.setStringList(AppConstants.keySearchHistory, list);
    return list;
  }

  /// 清空所有搜索历史
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keySearchHistory);
  }
}
