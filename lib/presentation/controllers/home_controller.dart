import 'package:get/get.dart';
import 'package:videohub/data/models/category.dart';
import 'package:videohub/data/repositories/category_repository.dart';
import 'package:videohub/data/repositories/video_repository.dart';
import 'package:videohub/data/models/video.dart';

/// 首页控制器
///
/// **分类菜单 Tab 设计**（参考网页导航菜单 + ui-ux-pro-max MD3 风格）：
/// - 顶部固定 Tab 栏：推荐 + 各分类
/// - 选中"推荐"：保留原 Section 布局，所有分类都展示前 6 条
/// - 选中具体分类：只展示该分类的视频网格，分页加载
class HomeController extends GetxController {
  final CategoryRepository _categoryRepo;
  final VideoRepository _videoRepo;

  HomeController(this._categoryRepo, this._videoRepo);

  final RxList<Category> categories = <Category>[].obs;
  final RxMap<int, List<Video>> categoryVideos = <int, List<Video>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString error = RxString('');

  /// 当前选中的分类 ID
  ///
  /// - null：选中"推荐"Tab，显示所有分类 section
  /// - 非 null：选中具体分类，只显示该分类的视频网格
  final Rx<int?> selectedCategoryId = Rx<int?>(null);

  /// 单分类 Tab 选中时的视频列表
  final RxList<Video> selectedCategoryVideos = <Video>[].obs;

  /// 单分类 Tab 的当前页码
  int _selectedPage = 1;

  /// 单分类 Tab 是否还有更多
  final RxBool selectedHasMore = true.obs;

  /// 单分类 Tab 是否正在加载第一页（独立于 [isLoading]，避免切换 Tab 时影响首页整体状态）
  final RxBool selectedLoading = false.obs;

  /// 单分类 Tab 是否正在加载更多
  final RxBool selectedLoadingMore = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    isLoading.value = true;
    error.value = '';
    try {
      // 1. 分类
      final cats =
          await _categoryRepo.getCategories(forceRefresh: forceRefresh);
      categories.value = cats;

      // 2. 各分类首页视频（并发拉取前 3 个分类，用于"推荐"Tab 展示）
      final futures = cats.take(3).map((c) async {
        final videos = await _videoRepo.getCategoryVideos(
          c.id,
          forceRefresh: forceRefresh,
        );
        categoryVideos[c.id] = videos;
      });
      await Future.wait(futures);
    } catch (e) {
      error.value = e.toString();
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

  /// 切换选中的分类 Tab
  ///
  /// [categoryId]：
  /// - null：选中"推荐"Tab，显示所有分类 section
  /// - 非 null：选中具体分类，加载并展示该分类的视频
  Future<void> selectCategory(int? categoryId) async {
    if (selectedCategoryId.value == categoryId) return;
    selectedCategoryId.value = categoryId;

    if (categoryId == null) {
      // 切回推荐：清空单分类 Tab 数据
      selectedCategoryVideos.clear();
      return;
    }

    // 选中具体分类：加载第一页
    selectedCategoryVideos.clear();
    selectedHasMore.value = true;
    _selectedPage = 1;
    await _loadSelectedCategoryFirstPage(categoryId);
  }

  Future<void> _loadSelectedCategoryFirstPage(int categoryId) async {
    selectedLoading.value = true;
    try {
      final videos = await _videoRepo.getCategoryVideos(categoryId);
      selectedCategoryVideos.value = videos;
      if (videos.isEmpty) {
        selectedHasMore.value = false;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      selectedLoading.value = false;
    }
  }

  /// 单分类 Tab：加载下一页
  Future<void> loadMoreSelectedCategory() async {
    final categoryId = selectedCategoryId.value;
    if (categoryId == null) return;
    if (selectedLoadingMore.value ||
        !selectedHasMore.value ||
        selectedLoading.value) return;

    selectedLoadingMore.value = true;
    try {
      final next = _selectedPage + 1;
      final videos = await _videoRepo.getCategoryVideos(categoryId, page: next);
      if (videos.isEmpty) {
        selectedHasMore.value = false;
      } else {
        selectedCategoryVideos.addAll(videos);
        _selectedPage = next;
      }
    } catch (_) {
      // 静默失败
    } finally {
      selectedLoadingMore.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await loadData(forceRefresh: true);
    // 刷新当前选中的 Tab
    final categoryId = selectedCategoryId.value;
    if (categoryId != null) {
      await _loadSelectedCategoryFirstPage(categoryId);
    }
  }
}
