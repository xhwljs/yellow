import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';

/// 历史记录控制器
class HistoryController extends GetxController {
  final HistoryRepository _historyRepo;
  HistoryController(this._historyRepo);

  final RxList<PlayHistory> histories = <PlayHistory>[].obs;
  final RxBool isLoading = false.obs;

  /// 加载失败时的错误信息（非空表示当前处于错误态）
  ///
  /// UI 层据此展示 [ErrorView] + 重试按钮，避免静默失败让用户误以为"无历史"。
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await _historyRepo.getAllHistory();
      histories.value = result;
    } catch (e, st) {
      appLogger.e('loadHistory failed', error: e, stackTrace: st);
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteHistory(String videoId) async {
    await _historyRepo.deleteByVideoId(videoId);
    histories.removeWhere((h) => h.videoId == videoId);
  }

  Future<void> clearAll() async {
    await _historyRepo.clearAll();
    histories.clear();
  }
}
