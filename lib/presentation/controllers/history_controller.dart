import 'package:get/get.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';

/// 历史记录控制器
class HistoryController extends GetxController {
  final HistoryRepository _historyRepo;
  HistoryController(this._historyRepo);

  final RxList<PlayHistory> histories = <PlayHistory>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      final result = await _historyRepo.getAllHistory();
      histories.value = result;
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
