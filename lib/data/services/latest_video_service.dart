import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/parser/recent_update_parser.dart';
import 'package:yellow_depot/core/parser/rss_parser.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/video.dart';

/// 最新上架服务（N2：首页"最新"Tab 数据源）
///
/// 数据链路（双源合并）：
/// 1. `/rss.xml`（[ApiService.fetchRss]）→ [RssParser]：
///    约 30 条，含精确发布时间（相对展示），但**无封面**
/// 2. 首页"最近更新"区块（[ApiService.fetchHomeHtml]）→
///    [RecentUpdateParser]：约 40 条，含封面 / 时长 / 干净标题，
///    与 RSS 同源（aid 序列一致）
///
/// 合并策略：以 RSS 顺序（时间序）为基，按 videoId 匹配补全
/// 封面 / 时长 / 干净标题（RSS 标题带时长尾巴）；首页区块独有条目
/// （RSS 未覆盖）追加到尾部。任一源失败 → 降级用另一源。
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

    // 缓存缺失或过期 → 拉取刷新（RSS 主源）
    try {
      final xml = await ApiService().fetchRss();
      var videos = RssParser.parse(xml);
      if (videos.isEmpty) {
        appLogger.w('RssParser 解析结果为空，回退缓存(${cached.length}条)');
        if (cached.isNotEmpty) return cached;
        throw Exception('RSS 内容为空');
      }

      // 封面补全：首页"最近更新"区块（增强能力，失败不阻断）
      videos = await _mergeWithRecentBlock(videos);

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

  /// 用首页"最近更新"区块补全 RSS 条目的封面 / 时长 / 干净标题
  ///
  /// - 按 videoId（aid-1-1）匹配，RSS 顺序（时间序）保持不变
  /// - RSS 标题带时长尾巴（"xxx 50:31"），首页区块标题干净 → 覆盖
  /// - 首页区块独有条目（RSS 30 条之外）追加尾部（无相对时间，仅 MM-DD）
  /// - 首页拉取 / 解析失败 → 原样返回（封面留空由占位图兜底）
  static Future<List<Video>> _mergeWithRecentBlock(List<Video> rssVideos) async {
    try {
      final homeHtml = await ApiService().fetchHomeHtml();
      final recent = RecentUpdateParser().parse(homeHtml);
      if (recent.isEmpty) return rssVideos;

      final recentById = {for (final r in recent) r.id: r};
      final merged = <Video>[];
      final seenIds = <String>{};
      for (final v in rssVideos) {
        final r = recentById[v.id];
        merged.add(r == null
            ? v
            : v.copyWith(
                title: r.title.isNotEmpty ? r.title : v.title,
                coverUrl: r.coverUrl,
                duration: r.duration.isNotEmpty ? r.duration : v.duration,
              ));
        seenIds.add(v.id);
      }
      for (final r in recent) {
        if (!seenIds.contains(r.id)) merged.add(r);
      }
      appLogger
          .i('最新上架封面补全：RSS ${rssVideos.length} 条 + 独有 ${merged.length - rssVideos.length} 条');
      return merged;
    } catch (e) {
      appLogger.w('最近更新区块补全失败（保持 RSS 原样）', error: e);
      return rssVideos;
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
