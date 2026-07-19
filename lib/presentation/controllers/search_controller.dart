import 'dart:async';
import 'package:get/get.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/repositories/video_repository.dart';

/// 搜索控制器
///
/// 严格遵循 ui-ux-pro-max Search UX 建议：
/// - Debounced fetch（500ms 防抖，避免每次按键都请求）
/// - "No results" 时给出建议而非空白屏
/// - 历史搜索关键字（简化版：仅内存中保留本次会话）
class SearchController extends GetxController {
  final VideoRepository _videoRepo;

  SearchController(this._videoRepo);

  /// 搜索关键字（双向绑定）
  final RxString keyword = ''.obs;

  /// 搜索结果列表
  final RxList<Video> results = <Video>[].obs;

  /// 加载状态
  final RxBool isLoading = false.obs;

  /// 错误信息
  final RxString error = ''.obs;

  /// 是否已经发起过搜索（用于区分初始空态 vs 无结果）
  final RxBool hasSearched = false.obs;

  /// 当前页码
  int _currentPage = 1;

  /// 是否还有更多
  final RxBool hasMore = true.obs;

  /// 是否正在加载更多
  final RxBool isLoadingMore = false.obs;

  /// 搜索防抖 Timer
  Timer? _debounce;

  /// 文本输入控制器
  final TextEditingController textController = TextEditingController();

  @override
  void onClose() {
    _debounce?.cancel();
    textController.dispose();
    super.onClose();
  }

  /// 输入框文本变化 — 500ms 防抖后触发搜索
  void onKeywordChanged(String text) {
    keyword.value = text;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      // 清空时立即重置状态
      results.clear();
      hasSearched.value = false;
      error.value = '';
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      search(text);
    });
  }

  /// 提交搜索（点击键盘搜索按钮或搜索 icon）
  void submitSearch() {
    _debounce?.cancel();
    final text = keyword.value.trim();
    if (text.isEmpty) return;
    search(text);
  }

  /// 执行搜索（首页）
  Future<void> search(String text) async {
    keyword.value = text;
    isLoading.value = true;
    error.value = '';
    hasSearched.value = true;
    _currentPage = 1;
    hasMore.value = true;
    try {
      final list = await _videoRepo.searchVideos(text, page: 1);
      results.value = list;
      if (list.isEmpty) {
        hasMore.value = false;
      }
    } catch (e) {
      error.value = e.toString();
      results.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载下一页
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading.value) return;
    final text = keyword.value.trim();
    if (text.isEmpty) return;

    isLoadingMore.value = true;
    try {
      final next = _currentPage + 1;
      final list = await _videoRepo.searchVideos(text, page: next);
      if (list.isEmpty) {
        hasMore.value = false;
      } else {
        results.addAll(list);
        _currentPage = next;
      }
    } catch (_) {
      // 加载更多失败静默
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// 清空搜索
  void clear() {
    textController.clear();
    keyword.value = '';
    results.clear();
    hasSearched.value = false;
    error.value = '';
    hasMore.value = true;
    _currentPage = 1;
  }
}
