import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';

/// 分类页控制器
///
/// **分页加载策略**：
/// - 第一页：[loadFirstPage]，清空现有列表，加载 categoryId 第 1 页
/// - 加载更多：[loadMore]，拉取下一页 append 到列表尾部
/// - 失败时：第一页错误显示在 UI（[errorMessage]），加载更多静默失败
///   （避免重置已有列表），但记日志便于排查
/// - [hasMore] = false 时不再触发 loadMore
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
    } catch (e, st) {
      appLogger.e('CategoryController.loadFirstPage 失败',
          error: e, stackTrace: st);
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading.value) return;
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
    } catch (e, st) {
      // 加载更多失败不重置列表，但记日志便于排查
      // （418/unknown 等暂态错误已被 RetryInterceptor 自动重试，
      //   重试 3 次仍失败才会进入这里，通常是网络持续不可用）
      appLogger.w('CategoryController.loadMore 失败 (categoryId=$categoryId page=${currentPage.value + 1})',
          error: e, stackTrace: st);
    } finally {
      isLoadingMore.value = false;
    }
  }

  @override
  Future<void> refresh() => loadFirstPage(forceRefresh: true);
}
