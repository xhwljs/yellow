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

  /// 各分类 Tab 的页面状态（按分类独立存储）
  ///
  /// PageView 滑动切换 Tab 时相邻两页并排可见，且各页 KeepAlive
  /// 常驻保活 — 单一全局状态会导致旧页瞬间显示新页的数据（视觉跳变），
  /// 因此每个分类持有独立的 videos/loading/分页状态。
  final RxMap<int, CategoryPageState> categoryPageStates =
      <int, CategoryPageState>{}.obs;

  /// 取分类的页面状态（不存在时创建）
  CategoryPageState stateOf(int categoryId) =>
      categoryPageStates.putIfAbsent(categoryId, CategoryPageState.new);

  /// 确保分类页已开始加载
  ///
  /// PageView 预构建相邻页（拖动时进入缓存区）即触发，
  /// 松手切页前数据已在加载 — 滑动切换零等待。
  void ensureCategoryLoaded(int categoryId) {
    final state = stateOf(categoryId);
    if (state.videos.isEmpty && !state.loading.value && state.error.isEmpty) {
      _loadCategoryFirstPage(categoryId);
    }
  }

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
  ///
  /// 分类页状态独立存储：无缓存时加载第一页，切回已缓存分类
  /// 直接显示缓存（瞬时），数据由下拉刷新统一更新。
  Future<void> selectCategory(int? categoryId) async {
    if (selectedCategoryId.value == categoryId) return;
    selectedCategoryId.value = categoryId;

    if (categoryId == null) return;

    if (categoryId == latestTabId) {
      // 选中"最新"：加载 RSS 最新上架（有缓存时几乎瞬时）
      await loadLatestVideos();
      return;
    }

    // 选中具体分类：无缓存才加载第一页（有缓存直接显示）
    final state = stateOf(categoryId);
    if (state.videos.isEmpty && !state.loading.value) {
      await _loadCategoryFirstPage(categoryId);
    }
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

  /// 加载分类第一页（写入该分类独立状态）
  Future<void> _loadCategoryFirstPage(int categoryId) async {
    final state = stateOf(categoryId);
    state.loading.value = true;
    state.error.value = '';
    try {
      final videos = await _videoRepo.getCategoryVideos(categoryId);
      state.videos.value = videos;
      if (videos.isEmpty) {
        state.hasMore.value = false;
      }
    } catch (e) {
      state.error.value = e.toString();
    } finally {
      state.loading.value = false;
    }
  }

  /// 重新加载指定分类第一页（清空缓存后加载，供错误重试/空态刷新）
  Future<void> reloadCategory(int categoryId) async {
    final state = stateOf(categoryId);
    state.videos.clear();
    state.page = 1;
    state.hasMore.value = true;
    await _loadCategoryFirstPage(categoryId);
  }

  /// 分类 Tab：加载下一页（按分类独立防重入）
  Future<void> loadMoreCategory(int categoryId) async {
    final state = stateOf(categoryId);
    if (state.loadingMore.value || !state.hasMore.value || state.loading.value) {
      return;
    }

    state.loadingMore.value = true;
    try {
      final next = state.page + 1;
      final videos = await _videoRepo.getCategoryVideos(categoryId, page: next);
      if (videos.isEmpty) {
        state.hasMore.value = false;
      } else {
        state.videos.addAll(videos);
        state.page = next;
      }
    } catch (e, st) {
      appLogger.w('loadMoreCategory 失败: categoryId=$categoryId',
          error: e, stackTrace: st);
    } finally {
      state.loadingMore.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await loadData(forceRefresh: true);
    // 并发刷新所有已缓存的分类页第一页（各页 KeepAlive 常驻，数据统一更新）
    await Future.wait([
      ...categoryPageStates.keys.map(_loadCategoryFirstPage),
      // "最新"Tab 已加载过（用户看过）才强制刷新 RSS
      if (latestVideos.isNotEmpty)
        loadLatestVideos(forceRefresh: true),
    ]);
  }
}

/// 单个分类 Tab 的页面状态（按分类独立）
///
/// PageView 滑动切换 + KeepAlive 常驻的配套设计：
/// 每个分类 Tab 持有独立的视频列表 / 加载 / 分页状态，
/// 相邻页并排可见时互不串数据，切回时保留已加载内容与滚动位置。
class CategoryPageState {
  /// 该分类的视频列表
  final RxList<Video> videos = <Video>[].obs;

  /// 是否正在加载第一页
  final RxBool loading = false.obs;

  /// 是否正在加载更多
  final RxBool loadingMore = false.obs;

  /// 是否还有更多（分页结束标记）
  final RxBool hasMore = true.obs;

  /// 错误信息（非空表示错误态）
  final RxString error = RxString('');

  /// 当前已加载到的页码
  int page = 1;
}
