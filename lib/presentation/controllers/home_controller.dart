import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/category.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/repositories/category_repository.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';
import 'package:yellow_depot/data/services/latest_video_service.dart';

/// 首页控制器
///
/// **分类菜单 Tab 设计**（参考网页导航菜单 + ui-ux-pro-max MD3 风格）：
/// - 顶部固定 Tab 栏：推荐 + 最新 + 各分类
/// - 选中"推荐"：保留原 Section 布局，所有分类都展示前 6 条
/// - 选中"最新"（[latestTabId] 哨兵）：展示 RSS 最新上架流（约 30 条，无分页）
/// - 选中具体分类：只展示该分类的视频网格，分页加载
class HomeController extends GetxController {
  final CategoryRepository _categoryRepo;
  final VideoRepository _videoRepo;

  HomeController(this._categoryRepo, this._videoRepo);

  /// "最新"Tab 哨兵 ID（负值避免与真实分类 id 冲突）
  static const int latestTabId = -1;

  final RxList<Category> categories = <Category>[].obs;
  final RxMap<int, List<Video>> categoryVideos = <int, List<Video>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString error = RxString('');

  /// 当前选中的分类 ID
  ///
  /// - null：选中"推荐"Tab，显示所有分类 section
  /// - [latestTabId]：选中"最新"Tab，显示 RSS 最新上架流
  /// - 其他非 null：选中具体分类，只显示该分类的视频网格
  final Rx<int?> selectedCategoryId = Rx<int?>(null);

  /// "最新"Tab 的视频列表（RSS 数据源）
  final RxList<Video> latestVideos = <Video>[].obs;

  /// "最新"Tab 是否正在加载
  final RxBool latestLoading = false.obs;

  /// "最新"Tab 错误信息（非空表示错误态）
  final RxString latestError = RxString('');

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
      // 1. 分类（catalog + nav 合并，已通过 CategoryParser.markCatalog 标记 isCatalog）
      final cats =
          await _categoryRepo.getCategories(forceRefresh: forceRefresh);
      categories.value = cats;

      // 2. 各分类首页视频（并发拉取前 3 个 nav 分类，用于"推荐"Tab 展示）
      //
      // 推荐 sections 只展示 nav 分类（用户需求：首页展示不需要目录区块的列表），
      // 不为 catalog 分类预加载视频（catalog 分类通过右下角卷帘菜单跳转独立分类页查看）。
      final navCats = navCategories;
      final futures = navCats.take(3).map((c) async {
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

  /// "目录"区块分类（isCatalog=true）— 用于右下角卷帘菜单
  ///
  /// 来自首页 `.stui-pannel__menu` 区块，含 count 视频数量。
  /// 仅在卷帘菜单展示，不出现在顶部 Tab 和推荐 sections。
  List<Category> get catalogCategories =>
      categories.where((c) => c.isCatalog).toList(growable: false);

  /// 导航菜单分类（isCatalog=false）— 用于顶部 Tab + 推荐 sections
  ///
  /// 来自首页 `.stui-header__menu` 中"目录"区块没有的分类。
  /// 不出现在右下角卷帘菜单。
  List<Category> get navCategories =>
      categories.where((c) => !c.isCatalog).toList(growable: false);

  Future<void> loadCategoryVideos(int categoryId) async {
    if (categoryVideos.containsKey(categoryId)) return;
    try {
      final videos = await _videoRepo.getCategoryVideos(categoryId);
      categoryVideos[categoryId] = videos;
    } catch (e, st) {
      appLogger.w('loadCategoryVideos 失败: categoryId=$categoryId',
          error: e, stackTrace: st);
    }
  }

  /// 切换选中的分类 Tab
  ///
  /// [categoryId]：
  /// - null：选中"推荐"Tab，显示所有分类 section
  /// - [latestTabId]：选中"最新"Tab，加载 RSS 最新上架流
  /// - 其他非 null：选中具体分类，加载并展示该分类的视频
  Future<void> selectCategory(int? categoryId) async {
    if (selectedCategoryId.value == categoryId) return;
    selectedCategoryId.value = categoryId;

    if (categoryId == null) {
      // 切回推荐：清空单分类 Tab 数据
      selectedCategoryVideos.clear();
      return;
    }

    if (categoryId == latestTabId) {
      // 选中"最新"：加载 RSS 最新上架（有缓存时几乎瞬时）
      selectedCategoryVideos.clear();
      await loadLatestVideos();
      return;
    }

    // 选中具体分类：加载第一页
    selectedCategoryVideos.clear();
    selectedHasMore.value = true;
    _selectedPage = 1;
    await _loadSelectedCategoryFirstPage(categoryId);
  }

  /// 加载最新上架（RSS 数据源）
  ///
  /// 下拉刷新传 [forceRefresh]：true 强制绕过 TTL。
  Future<void> loadLatestVideos({bool forceRefresh = false}) async {
    if (latestLoading.value) return;
    latestLoading.value = true;
    latestError.value = '';
    try {
      final videos = await LatestVideoService.load(forceRefresh: forceRefresh);
      latestVideos.value = videos;
    } catch (e, st) {
      appLogger.w('loadLatestVideos 失败', error: e, stackTrace: st);
      latestError.value = e.toString();
    } finally {
      latestLoading.value = false;
    }
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
    } catch (e, st) {
      appLogger.w('loadMoreSelectedCategory 失败: categoryId=$categoryId',
          error: e, stackTrace: st);
    } finally {
      selectedLoadingMore.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await loadData(forceRefresh: true);
    // 刷新当前选中的 Tab
    final categoryId = selectedCategoryId.value;
    if (categoryId == latestTabId) {
      // "最新"Tab：强制绕过 TTL 刷新 RSS
      await loadLatestVideos(forceRefresh: true);
    } else if (categoryId != null) {
      await _loadSelectedCategoryFirstPage(categoryId);
    }
  }
}
