import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/presentation/controllers/search_controller.dart';
import 'package:yellow_depot/presentation/widgets/video_card.dart';

/// 搜索页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 顶部固定搜索框（带返回 + 输入 + 清空 + 搜索按钮）
/// - 500ms 防抖触发搜索
/// - 初始空态：占位图标 + 提示文案
/// - 加载中：骨架屏
/// - 无结果：友好提示 + "试试搜索…" 建议
/// - 错误：错误视图 + 重试
/// - 列表：2 列网格，下拉加载更多
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
        // 初始空态（含历史搜索记录）
        if (!controller.hasSearched.value && !controller.isLoading.value) {
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
            keyword: controller.keyword.value,
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
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          controller.loadMore();
        }
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
              '/detail',
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
                child: Obx(
                  () => TextField(
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
                      suffixIcon: controller.keyword.value.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                PhosphorIconsRegular.xCircle,
                                color: colors.onSurfaceMuted,
                                size: 20,
                              ),
                              onPressed: controller.clear,
                              tooltip: '清空',
                            )
                          : null,
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
/// 包含两部分：
/// 1. 顶部：搜索引导图标 + 标题 + 提示文案
/// 2. 历史搜索区：标题栏（"历史搜索" + "清空"按钮）+ Wrap（chip 列表）
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
          '输入关键词，回车或点击搜索按钮',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: DesignTokens.textCaption,
            color: colors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: DesignTokens.space2xl),
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

/// 无结果视图 — 给出搜索建议
class _NoResultView extends StatelessWidget {
  final ThemeColors colors;
  final String keyword;
  const _NoResultView({required this.colors, required this.keyword});

  /// 推荐搜索词（用于引导用户）
  static const _suggestions = ['国产', '日本', '欧美', 'CAWD', 'SSIS'];

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
              '未找到 "$keyword" 相关结果',
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
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              alignment: WrapAlignment.center,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.border),
                  labelStyle: TextStyle(
                    color: colors.primary,
                    fontSize: DesignTokens.textCaption,
                  ),
                  onPressed: () {
                    final c = Get.find<SearchController>();
                    c.textController.text = s;
                    c.search(s);
                  },
                );
              }).toList(),
            ),
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
