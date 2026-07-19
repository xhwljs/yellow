import 'package:get/get.dart';
import 'package:videohub/data/models/category.dart';
import 'package:videohub/data/repositories/category_repository.dart';
import 'package:videohub/data/repositories/video_repository.dart';
import 'package:videohub/data/models/video.dart';

/// 首页控制器
class HomeController extends GetxController {
  final CategoryRepository _categoryRepo;
  final VideoRepository _videoRepo;

  HomeController(this._categoryRepo, this._videoRepo);

  final RxList<Category> categories = <Category>[].obs;
  final RxMap<int, List<Video>> categoryVideos = <int, List<Video>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString? error = RxString('').obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    isLoading.value = true;
    error?.value = '';
    try {
      // 1. 分类
      final cats = await _categoryRepo.getCategories(forceRefresh: forceRefresh);
      categories.value = cats;

      // 2. 各分类首页视频（并发拉取前 3 个分类）
      final futures = cats.take(3).map((c) async {
        final videos = await _videoRepo.getCategoryVideos(
          c.id,
          forceRefresh: forceRefresh,
        );
        categoryVideos[c.id] = videos;
      });
      await Future.wait(futures);
    } catch (e) {
      error?.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCategoryVideos(int categoryId) async {
    if (categoryVideos.containsKey(categoryId)) return;
    try {
      final videos = await _videoRepo.getCategoryVideos(categoryId);
      categoryVideos[categoryId] = videos;
    } catch (_) {}
  }

  Future<void> refresh() async {
    await loadData(forceRefresh: true);
  }
}
