import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';

/// 已看标记服务（N5）
///
/// 维护「已观看视频 ID 集合」（来自播放历史，内存级 [RxSet]），
/// 供列表卡片（VideoCard）响应式展示"已看"角标。
///
/// 数据流：
/// - App 启动时全量加载一次（历史上限 500 条，一次轻量查询开销可忽略）
/// - 播放启动时实时 [markWatched]（与历史 upsert 同步，返回列表页即可见角标）
/// - 历史清空 / 导入 / 删除后调用 [refresh] 重建集合
class WatchedService extends GetxService {
  WatchedService(this._historyRepo);

  final HistoryRepository _historyRepo;

  /// 已观看 videoId 集合（内存）
  final RxSet<String> _watchedIds = <String>{}.obs;

  /// 已看条目计数（RxInt —— Obx 内读取以确保响应式依赖注册，
  /// RxSet.contains 不保证触发 GetX 依赖收集）
  final RxInt watchedCount = 0.obs;

  /// 是否已看
  bool isWatched(String videoId) => _watchedIds.contains(videoId);

  /// 单条标记已看（不触发 DB 查询，播放启动时即时生效）
  void markWatched(String videoId) {
    _watchedIds.add(videoId);
    watchedCount.value = _watchedIds.length;
  }

  /// 从播放历史全量重建已看集合
  ///
  /// 历史上限 [AppConstants.historyMaxRecords]（500）条，
  /// 单次分页查询全部记录的 videoId，开销可忽略。
  Future<void> refresh() async {
    try {
      final list =
          await _historyRepo.getHistoryPage(limit: 500, offset: 0);
      _watchedIds.assignAll(
        list.map((h) => h.videoId).whereType<String>(),
      );
      watchedCount.value = _watchedIds.length;
      appLogger.d('已看集合刷新：${_watchedIds.length} 条');
    } catch (e, st) {
      appLogger.w('WatchedService.refresh 失败', error: e, stackTrace: st);
    }
  }
}
