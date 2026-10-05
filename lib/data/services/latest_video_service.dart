import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/parser/rss_parser.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/video.dart';

/// 最新上架服务（N2：首页"最新"Tab 数据源）
///
/// 数据链路：
/// `/rss.xml`（[ApiService.fetchRss]）→ [RssParser] 解析 →
/// SharedPreferences 缓存（Video JSON List）。
///
/// 缓存策略（同 [HotKeywordService] 模式）：
/// - TTL 内（[AppConstants.latestVideosCacheTtl]，1 小时）直接读缓存
/// - 过期则拉取刷新；拉取失败 / 解析为空时回退旧缓存
/// - 首次无缓存且失败 → 抛出异常（由 UI 显示错误态 + 重试）
class LatestVideoService {
  LatestVideoService._();

  /// 加载最新上架视频列表
  ///
  /// [forceRefresh] 为 true 时忽略 TTL 强制刷新（下拉刷新场景）。
  /// 缓存命中或网络成功 → 返回列表（可能为空）；
  /// 无可用数据 → 重新抛出底层异常。
  static Future<List<Video>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJsonList =
        prefs.getStringList(AppConstants.keyLatestVideosCache) ?? [];
    final cachedTs = prefs.getInt(AppConstants.keyLatestVideosCacheTs) ?? 0;
    final isFresh = DateTime.now().millisecondsSinceEpoch - cachedTs <
        AppConstants.latestVideosCacheTtl.inMilliseconds;

    final cached = _decode(cachedJsonList);
    if (!forceRefresh && cached.isNotEmpty && isFresh) {
      return cached;
    }

    // 缓存缺失或过期 → 拉取刷新
    try {
      final xml = await ApiService().fetchRss();
      final videos = RssParser.parse(xml);
      if (videos.isEmpty) {
        appLogger.w('RssParser 解析结果为空，回退缓存(${cached.length}条)');
        if (cached.isNotEmpty) return cached;
        throw Exception('RSS 内容为空');
      }
      await prefs.setStringList(
        AppConstants.keyLatestVideosCache,
        videos.map((v) => jsonEncode(v.toMap())).toList(),
      );
      await prefs.setInt(AppConstants.keyLatestVideosCacheTs,
          DateTime.now().millisecondsSinceEpoch);
      return videos;
    } catch (e, st) {
      appLogger.w('最新上架拉取失败', error: e, stackTrace: st);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// 反序列化缓存的 Video 列表（逐条容错，坏条目跳过）
  static List<Video> _decode(List<String> jsonList) {
    final videos = <Video>[];
    for (final s in jsonList) {
      try {
        final map = jsonDecode(s);
        if (map is Map<String, dynamic>) {
          videos.add(Video.fromMap(map));
        }
      } catch (_) {
        // 单条损坏跳过，不影响其余缓存
      }
    }
    return videos;
  }
}
