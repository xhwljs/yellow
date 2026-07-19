import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/data/models/category.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/presentation/controllers/home_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

/// 首页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 顶部 AppBar 标题 "VideoHub" 使用主题色 primary
/// - **分类菜单 Tab**（pill-shaped，参考 ui-ux-pro-max MD3 风格）：
///   - 横向滚动 Tab 栏：推荐 + 各分类（来自站点导航菜单）
///   - 选中态：primary 背景 + onPrimary 文字（pill 形状）
///   - 未选中态：surface 背景 + onSurfaceMuted 文字 + outline 边框
///   - 切换 Tab 时切换内容，不跳转
/// - "推荐"Tab：保留原 Section 布局，每个分类横向滚动 6 条
/// - 具体分类 Tab：网格布局 + 分页懒加载
/// - 下拉刷新 / 加载骨架屏 / 错误 / 空数据三态
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppConstants.appName,
          style: TextStyle(
            color: colors.primary,
            fontSize: DesignTokens.textDisplay,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.categories.isEmpty) {
          return _buildSkeletonGrid();
        }
        final errMsg = controller.error.value;
        if (errMsg.isNotEmpty && controller.categories.isEmpty) {
          return ErrorView(message: errMsg, onRetry: controller.refresh);
        }
        if (controller.categories.isEmpty) {
          return EmptyView(
            icon: PhosphorIconsRegular.filmSlate,
            title: '暂无内容',
            subtitle: '下拉刷新试试',
            onAction: controller.refresh,
            actionLabel: '刷新',
          );
        }
        return RefreshIndicator(
          color: colors.primary,
          onRefresh: controller.refresh,
          child: Column(
            children: [
              // 顶部搜索入口（固定）
              _buildSearchEntry(colors),
              const SizedBox(height: DesignTokens.spaceMd),
              // 分类菜单 Tab 栏（固定）
              _buildCategoryTabs(colors),
              const SizedBox(height: DesignTokens.spaceMd),
              // 内容区（根据 Tab 切换）
              Expanded(
                child: Obx(() {
                  final selectedId = controller.selectedCategoryId.value;
                  if (selectedId == null) {
                    return _buildRecommendView(colors);
                  }
                  return _buildSingleCategoryView(colors, selectedId);
                }),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// 顶部搜索入口
  ///
  /// 设计参考 ui-ux-pro-max Search UX 建议：
  /// - 视觉上像搜索框（点击跳转搜索页），降低交互成本
  /// - 左侧搜索图标 + 占位文案 + 右侧快捷过滤 icon
  Widget _buildSearchEntry(colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
      ),
      child: GestureDetector(
        onTap: () => Get.toNamed('/search'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLg,
            vertical: DesignTokens.spaceMd,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            boxShadow: DesignTokens.elevation1,
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: Text(
                  '搜索视频…',
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: DesignTokens.textBody,
                  ),
                ),
              ),
              Icon(
                PhosphorIconsRegular.slidersHorizontal,
                size: 18,
                color: colors.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类菜单 Tab 栏（pill-shaped，参考 ui-ux-pro-max MD3 风格）
  ///
  /// 设计：
  /// - 横向滚动 Tab 列表（含"推荐" + 各分类）
  /// - 选中态：primary 背景 + onPrimary 文字 + elevation1 阴影
  /// - 未选中态：surface 背景 + onSurfaceMuted 文字 + outline 边框
  /// - pill 形状（radiusPill = 999）
  /// - 主题色切换时通过 Obx 自动重建
  Widget _buildCategoryTabs(colors) {
    return SizedBox(
      height: 40,
      child: Obx(() {
        final selectedId = controller.selectedCategoryId.value;
        // Tab 列表：推荐 + 各分类
        final tabs = <_CategoryTab>[
          _CategoryTab(id: null, name: '推荐'),
          ...controller.categories.map(
            (c) => _CategoryTab(id: c.id, name: c.name),
          ),
        ];
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
          ),
          itemCount: tabs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(width: DesignTokens.spaceSm),
          itemBuilder: (_, i) {
            final tab = tabs[i];
            final isSelected = tab.id == selectedId;
            return GestureDetector(
              onTap: () => controller.selectCategory(tab.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: DesignTokens.motionFast,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLg,
                  vertical: DesignTokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                  border: isSelected ? null : Border.all(color: colors.border),
                  boxShadow: isSelected ? DesignTokens.elevation1 : null,
                ),
                child: Center(
                  child: Text(
                    tab.name,
                    style: TextStyle(
                      color:
                          isSelected ? colors.onPrimary : colors.onSurfaceMuted,
                      fontSize: DesignTokens.textBody,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// "推荐"Tab 内容：所有分类 section（保留原布局）
  Widget _buildRecommendView(colors) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.spaceSm,
      ),
      children: [
        ...controller.categories.map(
          (c) => _buildCategorySection(
            colors,
            c,
            controller.categoryVideos[c.id] ?? const <Video>[],
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXl),
      ],
    );
  }

  /// 单分类 Tab 内容：网格布局 + 分页懒加载
  Widget _buildSingleCategoryView(colors, int categoryId) {
    return Obx(() {
      // 加载中（首次切换）
      if (controller.selectedLoading.value &&
          controller.selectedCategoryVideos.isEmpty) {
        return _buildSkeletonGrid();
      }
      // 错误
      if (controller.error.value.isNotEmpty &&
          controller.selectedCategoryVideos.isEmpty) {
        return ErrorView(
          message: controller.error.value,
          onRetry: () => controller.selectCategory(categoryId),
        );
      }
      // 无结果
      if (controller.selectedCategoryVideos.isEmpty) {
        return EmptyView(
          icon: PhosphorIconsRegular.filmSlate,
          title: '该分类暂无视频',
          subtitle: '下拉刷新试试',
          onAction: controller.refresh,
          actionLabel: '刷新',
        );
      }
      // 视频网格（带分页加载）
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >
                  notification.metrics.maxScrollExtent - 200 &&
              controller.selectedHasMore.value &&
              !controller.selectedLoadingMore.value) {
            controller.loadMoreSelectedCategory();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DesignTokens.videoGridCrossAxisCount,
            mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
            crossAxisSpacing: DesignTokens.videoGridSpacing,
            childAspectRatio: 0.65,
          ),
          itemCount: controller.selectedCategoryVideos.length +
              (controller.selectedLoadingMore.value ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= controller.selectedCategoryVideos.length) {
              return const VideoCardSkeleton();
            }
            final v = controller.selectedCategoryVideos[i];
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
    });
  }

  /// 加载骨架屏（2 列网格）
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: DesignTokens.videoGridCrossAxisCount,
        mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
        crossAxisSpacing: DesignTokens.videoGridSpacing,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const VideoCardSkeleton(),
    );
  }

  /// 单个分类区块（推荐 Tab 使用）：标题 + 横向视频网格
  Widget _buildCategorySection(
    colors,
    Category category,
    List<Video> videos,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignTokens.textH1,
                      fontWeight: FontWeight.w700,
                      color: colors.onBackground,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // 跳转到独立分类页（保留完整分页能力）
                    Get.toNamed('/category', arguments: category.id);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '更多',
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXs),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 14,
                          color: colors.onSurfaceMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
              ),
              child: Text(
                '暂无视频',
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  color: colors.onSurfaceMuted,
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                ),
                itemCount: videos.length > 6 ? 6 : videos.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: DesignTokens.spaceMd),
                itemBuilder: (_, i) {
                  final v = videos[i];
                  return SizedBox(
                    width: 160,
                    child: VideoCard(
                      video: v,
                      onTap: () => Get.toNamed(
                        '/detail',
                        arguments: {
                          'videoId': v.id,
                          'coverUrl': v.coverUrl,
                          'title': v.title,
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 分类 Tab 数据
class _CategoryTab {
  final int? id;
  final String name;

  const _CategoryTab({required this.id, required this.name});
}
