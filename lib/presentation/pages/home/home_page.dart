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
/// - 横向滚动分类 Chip 列表（chip 选中态用 primaryContainer）
/// - 每个分类下显示 6 个视频的水平网格（横向滚动）
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
          child: ListView(
            padding: const EdgeInsets.symmetric(
              vertical: DesignTokens.spaceMd,
            ),
            children: [
              _buildSearchEntry(colors),
              const SizedBox(height: DesignTokens.spaceLg),
              _buildCategoryChips(colors, controller.categories),
              const SizedBox(height: DesignTokens.spaceLg),
              ...controller.categories.map(
                (c) => _buildCategorySection(
                  colors,
                  c,
                  controller.categoryVideos[c.id] ?? const <Video>[],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXl),
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

  /// 横向分类 Chip 列表
  Widget _buildCategoryChips(colors, List<Category> categories) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DesignTokens.spaceSm),
        itemBuilder: (_, i) {
          final c = categories[i];
          return GestureDetector(
            onTap: () => Get.toNamed('/category', arguments: c.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceLg,
                vertical: DesignTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
              ),
              child: Center(
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: DesignTokens.textBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 单个分类区块：标题 + 横向视频网格
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
                  onTap: () => Get.toNamed('/category', arguments: category.id),
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
