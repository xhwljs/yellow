import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';
import 'package:yellow_depot/data/services/hot_keyword_service.dart';
import 'package:yellow_depot/data/services/search_history_service.dart';
import 'package:yellow_depot/data/services/search_suggest_service.dart';

/// 搜索控制器
///
/// 交互模型（联想 + 提交式搜索）：
/// - 输入变化 → 350ms 防抖触发**实时联想**（suggest JSON 接口，
///   封面 + 标题，点击联想项直达详情页）
/// - 回车 / 搜索按钮 / 历史词条 / 热门词条点击 → 提交**完整搜索**
///   （vodsearch HTML 链路，支持分页）
/// - 初始空态展示：历史搜索 + 热门搜索词条（/topic.html header 解析，
///   SP 缓存 12h）
///
/// 说明：早期版本为"输入 500ms 自动执行完整搜索"，与联想层冲突
/// （自动搜索会立即切走空态，联想项来不及点击），故调整为提交式。
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

  /// 热门搜索词条（站点 /topic.html header 解析，SP 缓存 12h）
  ///
  /// 展示在初始空态的历史搜索区上方；无结果时也作为推荐搜索词。
  final RxList<String> hotKeywords = <String>[].obs;

  /// 实时联想列表（suggest JSON 接口）
  final RxList<SearchSuggestion> suggestions = <SearchSuggestion>[].obs;

  /// 联想加载中
  final RxBool isSuggestLoading = false.obs;

  /// 联想请求序号（防竞态：仅最新请求的响应才更新列表）
  int _suggestSeq = 0;

  /// 联想防抖 Timer
  Timer? _suggestDebounce;

  /// 文本输入控制器
  final TextEditingController textController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
    _loadHotKeywords();
  }

  @override
  void onClose() {
    _suggestDebounce?.cancel();
    textController.dispose();
    super.onClose();
  }

  /// 加载搜索历史到 Rx
  Future<void> _loadHistory() async {
    history.value = await SearchHistoryService.load();
  }

  /// 加载热门搜索词条（失败静默，区域不显示）
  Future<void> _loadHotKeywords() async {
    try {
      hotKeywords.value = await HotKeywordService.load();
    } catch (e, st) {
      appLogger.w('热门词条加载失败', error: e, stackTrace: st);
    }
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

  /// 输入框文本变化 — 350ms 防抖触发实时联想
  ///
  /// 联想层仅展示在初始空态（hasSearched=false）；
  /// 提交搜索（回车/按钮/词条点击）后由 [search] 清空联想。
  void onKeywordChanged(String text) {
    keyword.value = text;
    _suggestDebounce?.cancel();

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      // 清空时立即重置：联想 + 结果状态
      suggestions.clear();
      isSuggestLoading.value = false;
      results.clear();
      hasSearched.value = false;
      error.value = '';
      return;
    }

    isSuggestLoading.value = true;
    _suggestDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(trimmed);
    });
  }

  /// 请求联想（带竞态保护）
  Future<void> _fetchSuggestions(String text) async {
    final seq = ++_suggestSeq;
    final list = await SearchSuggestService.suggest(text);
    // 仅最新请求生效（用户可能已继续输入或已提交搜索）
    if (seq != _suggestSeq || isClosed) return;
    suggestions.value = list;
    isSuggestLoading.value = false;
  }

  /// 提交搜索（点击键盘搜索按钮或搜索 icon）
  void submitSearch() {
    _suggestDebounce?.cancel();
    final text = keyword.value.trim();
    if (text.isEmpty) return;
    search(text);
  }

  /// 执行搜索（首页）
  Future<void> search(String text) async {
    // 提交搜索：联想层退场
    _suggestSeq++;
    _suggestDebounce?.cancel();
    suggestions.clear();
    isSuggestLoading.value = false;

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
    } catch (e, st) {
      // 加载更多失败静默（避免重置已有列表），但记日志便于排查
      appLogger.w(
        'SearchController.loadMore 失败 (keyword=$text page=${_currentPage + 1})',
        error: e,
        stackTrace: st,
      );
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// 清空搜索（保留历史）
  void clear() {
    _suggestSeq++;
    _suggestDebounce?.cancel();
    textController.clear();
    keyword.value = '';
    suggestions.clear();
    isSuggestLoading.value = false;
    results.clear();
    hasSearched.value = false;
    error.value = '';
    hasMore.value = true;
    _currentPage = 1;
  }
}
