import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/data/services/search_suggest_service.dart';
import 'package:yellow_depot/presentation/controllers/search_controller.dart';
import 'package:yellow_depot/presentation/routes/app_pages.dart';
import 'package:yellow_depot/presentation/widgets/video_card.dart';

/// 搜索页
///
/// 交互模型（联想 + 提交式搜索）：
/// - 顶部固定搜索框（带返回 + 输入 + 清空 + 搜索按钮）
/// - 输入 350ms 防抖触发实时联想（封面 + 标题，点击直达详情页）
/// - 初始空态：占位图标 + 热门搜索词条 + 历史搜索记录
/// - 提交搜索（回车/按钮/词条点击）后：加载骨架 → 结果网格（分页）
/// - 无结果：友好提示 + 热门词条推荐
/// - 错误：错误视图 + 重试
class SearchPage extends GetView<SearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _SearchAppBar(controller: controller),
      ),
      body: Obx(() {
        // 初始空态（未搜索）
        if (!controller.hasSearched.value && !controller.isLoading.value) {
          // 已输入文字 → 联想层；否则初始空态（热门 + 历史）
          if (controller.keyword.value.trim().isNotEmpty) {
            return _SuggestView(
              colors: colors,
              controller: controller,
            );
          }
          return _InitialEmptyView(
            colors: colors,
            controller: controller,
          );
        }
        // 加载中（首次搜索）
        if (controller.isLoading.value && controller.results.isEmpty) {
          return _buildSkeletonGrid();
        }
        // 错误
        if (controller.error.value.isNotEmpty && controller.results.isEmpty) {
          return ErrorView(
            message: controller.error.value,
            onRetry: () => controller.search(controller.keyword.value),
          );
        }
        // 无结果
        if (controller.results.isEmpty) {
          return _NoResultView(
            colors: colors,
            controller: controller,
          );
        }
        // 结果列表
        return _buildResults(colors);
      }),
    );
  }

  Widget _buildResults(ThemeColors colors) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 滚动接近底部时加载下一页
        // - 仅在 ScrollEndNotification 或 OverscrollNotification 时触发，
        //   避免滑动过程中频繁调用
        // - 显式 UI 层锁：isLoadingMore / isLoading / !hasMore 都跳过，
        //   controller.loadMore 内部也有锁，这里提前 return 避免冗余调用
        final isEnd = notification is ScrollEndNotification;
        final isOverScroll = notification is OverscrollNotification &&
            notification.overscroll > 0;
        if (!isEnd && !isOverScroll) return false;
        if (notification.metrics.pixels <
            notification.metrics.maxScrollExtent - 200) {
          return false;
        }
        if (controller.isLoadingMore.value ||
            controller.isLoading.value ||
            !controller.hasMore.value) {
          return false;
        }
        controller.loadMore();
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: DesignTokens.videoGridCrossAxisCount,
          mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
          crossAxisSpacing: DesignTokens.videoGridSpacing,
          childAspectRatio: 0.88,
        ),
        itemCount: controller.results.length + 1,
        itemBuilder: (_, i) {
          if (i == controller.results.length) {
            return Obx(() {
              if (controller.isLoadingMore.value) {
                return const _GridFooterLoading();
              }
              if (!controller.hasMore.value) {
                return const _GridFooterEnd();
              }
              return const SizedBox.shrink();
            });
          }
          final v = controller.results[i];
          return VideoCard(
            video: v,
            onTap: () => Get.toNamed(
              AppPages.detail,
              arguments: {
                'videoId': v.id,
                'coverUrl': v.coverUrl,
                'title': v.title,
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: DesignTokens.videoGridCrossAxisCount,
        mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
        crossAxisSpacing: DesignTokens.videoGridSpacing,
        childAspectRatio: 0.88,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const VideoCardSkeleton(),
    );
  }
}

/// 顶部搜索栏 — 含返回按钮、输入框、清空、搜索提交
class _SearchAppBar extends StatelessWidget {
  final SearchController controller;
  const _SearchAppBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return SafeArea(
      bottom: false,
      child: Material(
        color: colors.surface,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSm,
            vertical: DesignTokens.spaceSm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: colors.onSurface,
                ),
                onPressed: () => Get.back(),
                tooltip: '返回',
              ),
              Expanded(
                child: TextField(
                  controller: controller.textController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: controller.onKeywordChanged,
                  onSubmitted: (_) => controller.submitSearch(),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: DesignTokens.textBody,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索视频…',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: DesignTokens.textBody,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: colors.primary,
                      size: 20,
                    ),
                    suffixIcon: Obx(
                      () => controller.keyword.value.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                PhosphorIconsRegular.xCircle,
                                color: colors.onSurfaceMuted,
                                size: 20,
                              ),
                              onPressed: controller.clear,
                              tooltip: '清空',
                            )
                          : const SizedBox.shrink(),
                    ),
                    filled: true,
                    fillColor: colors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMd,
                      vertical: DesignTokens.spaceSm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusPill,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusPill,
                      ),
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              Obx(
                () => TextButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.submitSearch,
                  child: Text(
                    '搜索',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: DesignTokens.textBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 初始空态（未搜索时）
///
/// 包含三部分：
/// 1. 顶部：搜索引导图标 + 标题 + 提示文案
/// 2. 热门搜索区：站方运营配置的快捷词条（/topic.html header 解析，
///    SP 缓存 12h），点击直接提交搜索；加载失败静默隐藏
/// 3. 历史搜索区：标题栏（"历史搜索" + "清空"按钮）+ Wrap（chip 列表）
///    - chip 显示关键字 + 单条删除按钮（x 图标）
///    - 点击 chip 文本 → 触发搜索
///    - 点击 x → 删除单条历史
///    - 点击"清空" → 弹出确认对话框 → 清空全部历史
///    - 无历史时整个区域不显示
class _InitialEmptyView extends StatelessWidget {
  final ThemeColors colors;
  final SearchController controller;

  const _InitialEmptyView({
    required this.colors,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceXl),
      children: [
        const SizedBox(height: DesignTokens.spaceXl),
        // 引导图标
        Icon(
          PhosphorIconsRegular.magnifyingGlass,
          size: 56,
          color: colors.onSurfaceMuted,
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        Text(
          '搜索你感兴趣的视频',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          '输入关键词实时联想，回车查看全部结果',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: DesignTokens.textCaption,
            color: colors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: DesignTokens.space2xl),
        // 热门搜索区（词条非空时显示）
        Obx(() {
          if (controller.hotKeywords.isEmpty) {
            return const SizedBox.shrink();
          }
          return _HotKeywordSection(
            colors: colors,
            keywords: controller.hotKeywords,
            onTap: (kw) => controller.search(kw),
          );
        }),
        const SizedBox(height: DesignTokens.spaceLg),
        // 历史搜索区（有记录时显示）
        Obx(() {
          if (controller.history.isEmpty) {
            return const SizedBox.shrink();
          }
          return _HistorySearchSection(
            colors: colors,
            controller: controller,
          );
        }),
      ],
    );
  }
}

/// 热门搜索区
///
/// 站方运营配置的快捷词条（来自 /topic.html header），点击提交搜索。
/// chip 采用胶囊样式：火焰图标 + 词条文本，主色调点缀。
class _HotKeywordSection extends StatelessWidget {
  final ThemeColors colors;
  final List<String> keywords;
  final ValueChanged<String> onTap;

  const _HotKeywordSection({
    required this.colors,
    required this.keywords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              PhosphorIconsRegular.fire,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: DesignTokens.spaceXs),
            Text(
              '热门搜索',
              style: TextStyle(
                fontSize: DesignTokens.textBody,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Wrap(
          spacing: DesignTokens.spaceSm,
          runSpacing: DesignTokens.spaceSm,
          children: keywords.map((kw) {
            return ActionChip(
              label: Text(
                kw,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: DesignTokens.textCaption,
                ),
              ),
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              visualDensity: VisualDensity.compact,
              onPressed: () => onTap(kw),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 实时联想视图（输入文字且未提交搜索时）
///
/// 三种状态：
/// - 联想加载中（列表为空）→ 3 条骨架行
/// - 有联想结果 → 联想项列表（封面缩略 + 标题 + 箭头），点击直达详情页
/// - 加载完成但无联想 → 轻提示 + 热门词条兜底（引导提交搜索）
class _SuggestView extends StatelessWidget {
  final ThemeColors colors;
  final SearchController controller;

  const _SuggestView({
    required this.colors,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isSuggestLoading.value;
      final items = controller.suggestions;

      if (loading && items.isEmpty) {
        return const _SuggestSkeleton();
      }
      if (items.isEmpty) {
        return _SuggestEmpty(colors: colors, controller: controller);
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceSm,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colors.border,
        ),
        itemBuilder: (_, i) {
          final s = items[i];
          return _SuggestItem(
            colors: colors,
            suggestion: s,
            onTap: () => Get.toNamed(
              AppPages.detail,
              arguments: {
                'videoId': s.videoId,
                'coverUrl': s.coverUrl,
                'title': s.title,
              },
            ),
          );
        },
      );
    });
  }
}

/// 联想项 — 封面缩略 + 标题 + 箭头
class _SuggestItem extends StatelessWidget {
  final ThemeColors colors;
  final SearchSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestItem({
    required this.colors,
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
        child: Row(
          children: [
            // 封面缩略（16:9）
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              child: SizedBox(
                width: 96,
                height: 54,
                child: CachedNetworkImage(
                  imageUrl: suggestion.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: colors.border),
                  errorWidget: (_, __, ___) => Container(
                    color: colors.border,
                    child: Icon(
                      PhosphorIconsRegular.image,
                      size: 20,
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            // 标题
            Expanded(
              child: Text(
                suggestion.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: DesignTokens.textBody,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: colors.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 联想骨架行
class _SuggestSkeleton extends StatelessWidget {
  const _SuggestSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceSm,
      ),
      children: List.generate(3, (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(color: colors.border),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(color: colors.border),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// 联想无结果 — 轻提示 + 热门词条兜底
class _SuggestEmpty extends StatelessWidget {
  final ThemeColors colors;
  final SearchController controller;

  const _SuggestEmpty({
    required this.colors,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceXl),
      children: [
        const SizedBox(height: DesignTokens.spaceLg),
        Text(
          '暂无联想结果，回车搜索全部内容',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: DesignTokens.textCaption,
            color: colors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: DesignTokens.space2xl),
        Obx(() {
          if (controller.hotKeywords.isEmpty) {
            return const SizedBox.shrink();
          }
          return _HotKeywordSection(
            colors: colors,
            keywords: controller.hotKeywords,
            onTap: (kw) => controller.search(kw),
          );
        }),
      ],
    );
  }
}

/// 历史搜索区
class _HistorySearchSection extends StatelessWidget {
  final ThemeColors colors;
  final SearchController controller;

  const _HistorySearchSection({
    required this.colors,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏：历史搜索 + 清空按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '历史搜索',
              style: TextStyle(
                fontSize: DesignTokens.textBody,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: _confirmClearAll,
              icon: Icon(
                PhosphorIconsRegular.trash,
                size: 16,
                color: colors.destructive,
              ),
              label: Text(
                '清空',
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  color: colors.destructive,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        // chip 列表
        Wrap(
          spacing: DesignTokens.spaceSm,
          runSpacing: DesignTokens.spaceSm,
          children: controller.history.map((keyword) {
            return _HistoryChip(
              keyword: keyword,
              colors: colors,
              onTap: () => controller.search(keyword),
              onDelete: () => controller.removeHistory(keyword),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 清空全部历史搜索记录确认对话框
  void _confirmClearAll() {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        title: Text(
          '清空历史搜索',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要清空所有历史搜索记录吗？此操作不可撤销。',
          style: TextStyle(
            color: colors.onSurfaceMuted,
            fontSize: DesignTokens.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Get.back();
              controller.clearHistory();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.destructive,
              foregroundColor: colors.surface,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// 单条历史搜索 chip
///
/// 设计：
/// - 圆角胶囊形状（radiusPill）
/// - 浅色背景 + 边框
/// - 左侧关键字文本（点击触发搜索）
/// - 右侧 x 图标（点击删除单条）
class _HistoryChip extends StatelessWidget {
  final String keyword;
  final ThemeColors colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryChip({
    required this.keyword,
    required this.colors,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 关键字（点击触发搜索）
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(DesignTokens.radiusPill),
              bottomLeft: Radius.circular(DesignTokens.radiusPill),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.spaceMd,
                top: 6,
                bottom: 6,
              ),
              child: Text(
                keyword,
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 删除按钮
          InkWell(
            onTap: onDelete,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(DesignTokens.radiusPill),
              bottomRight: Radius.circular(DesignTokens.radiusPill),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.spaceXs,
                right: 6,
                top: 6,
                bottom: 6,
              ),
              child: Icon(
                PhosphorIconsRegular.x,
                size: 14,
                color: colors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 无结果视图 — 给出搜索建议（优先热门词条，兜底静态推荐）
class _NoResultView extends StatelessWidget {
  final ThemeColors colors;
  final SearchController controller;
  const _NoResultView({required this.colors, required this.controller});

  /// 静态兜底推荐词（热门词条未加载时使用）
  static const _fallbackSuggestions = ['国产', '日本', '欧美', 'CAWD', 'SSIS'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 64,
              color: colors.onSurfaceMuted,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              '未找到 "${controller.keyword.value}" 相关结果',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.textH2,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              '试试简化关键词或更换搜索词',
              style: TextStyle(
                fontSize: DesignTokens.textCaption,
                color: colors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXl),
            Obx(() {
              // 推荐词：热门词条前 8 个；未加载时回退静态推荐
              final suggestions = controller.hotKeywords.isNotEmpty
                  ? controller.hotKeywords.take(8).toList()
                  : _fallbackSuggestions;
              return Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceSm,
                alignment: WrapAlignment.center,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s),
                    backgroundColor: colors.surface,
                    side: BorderSide(color: colors.border),
                    labelStyle: TextStyle(
                      color: colors.primary,
                      fontSize: DesignTokens.textCaption,
                    ),
                    onPressed: () {
                      controller.textController.text = s;
                      controller.search(s);
                    },
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 网格底部 — 加载更多
class _GridFooterLoading extends StatelessWidget {
  const _GridFooterLoading();
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

/// 网格底部 — 没有更多
class _GridFooterEnd extends StatelessWidget {
  const _GridFooterEnd();
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      child: Center(
        child: Text(
          '没有更多了',
          style: TextStyle(
            fontSize: DesignTokens.textCaption,
            color: colors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}
