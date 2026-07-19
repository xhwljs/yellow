import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/data/repositories/video_repository.dart';
import 'package:videohub/data/services/search_history_service.dart';

/// 搜索控制器
///
/// 严格遵循 ui-ux-pro-max Search UX 建议：
/// - Debounced fetch（500ms 防抖，避免每次按键都请求）
/// - "No results" 时给出建议而非空白屏
/// - 历史搜索关键字（SharedPreferences 持久化，最多 20 条）
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

  /// 搜索历史（持久化，按最近优先排序）
  ///
  /// 用户每次提交搜索后调用 [addToHistory] 上移到列表头部。
  /// 搜索页初始空态会展示此列表，支持点击 chip 快速搜索、
  /// 单条删除（x 按钮）和一键清空。
  final RxList<String> history = <String>[].obs;

  /// 搜索防抖 Timer
  Timer? _debounce;

  /// 文本输入控制器
  final TextEditingController textController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    textController.dispose();
    super.onClose();
  }

  /// 加载搜索历史到 Rx
  Future<void> _loadHistory() async {
    history.value = await SearchHistoryService.load();
  }

  /// 添加当前关键字到搜索历史
  ///
  /// 由 [submitSearch] / [search] 调用，去重并上移到头部。
  Future<void> _addKeywordToHistory(String text) async {
    final updated = await SearchHistoryService.add(text);
    history.value = updated;
  }

  /// 删除单条搜索历史
  Future<void> removeHistory(String keyword) async {
    final updated = await SearchHistoryService.remove(keyword);
    history.value = updated;
  }

  /// 清空全部搜索历史
  Future<void> clearHistory() async {
    await SearchHistoryService.clear();
    history.clear();
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
    textController.text = text;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
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
      // 搜索成功后记录到历史（即使无结果也保留关键字，方便重试）
      await _addKeywordToHistory(text);
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

  /// 清空搜索（保留历史）
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
