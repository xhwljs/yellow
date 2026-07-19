import 'package:get/get.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/repositories/video_repository.dart';

/// 分类页控制器
class CategoryController extends GetxController {
  final VideoRepository _videoRepo;
  final int categoryId;

  CategoryController(this._videoRepo, {required this.categoryId});

  final RxList<Video> videos = <Video>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadFirstPage();
  }

  Future<void> loadFirstPage({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await _videoRepo.getCategoryVideos(
        categoryId,
        page: 1,
        forceRefresh: forceRefresh,
      );
      videos.value = result;
      currentPage.value = 1;
      hasMore.value = result.isNotEmpty;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = currentPage.value + 1;
      final result = await _videoRepo.getCategoryVideos(
        categoryId,
        page: nextPage,
      );
      if (result.isEmpty) {
        hasMore.value = false;
      } else {
        videos.addAll(result);
        currentPage.value = nextPage;
      }
    } catch (_) {
      // 加载更多失败不重置列表
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> refresh() => loadFirstPage(forceRefresh: true);
}
