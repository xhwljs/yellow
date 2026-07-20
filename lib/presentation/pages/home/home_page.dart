import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_presets.dart';
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
/// - **悬浮目录按钮**（FAB，右下角）：
///   - 点击弹出卷帘式 BottomSheet，展示首页"目录"区块所有分类
///   - 每个分类显示名称 + 视频数量（来自站点 .stui-pannel__menu 的 count）
///   - 点击分类项跳转到独立分类页（保留完整分页能力）
///   - 不破坏现有首页结构（Tab 栏 + 内容区不变）
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
      // 右下角悬浮目录按钮 — 点击弹出卷帘式分类目录
      //
      // 仅当存在"目录"区块分类（catalog）时显示。
      // catalog 分类来自 `.stui-pannel__menu`（含 count 视频数量），
      // 不在顶部 Tab 和推荐 sections 中展示。
      //
      // 设计参考 ui-ux-pro-max FAB UX 建议：
      // - 不破坏现有首页结构（Tab 栏 + 内容区不变）
      // - 按钮固定在右下角，滚动时仍可见
      // - 不与底部导航栏冲突（FAB 默认位置在底部导航上方）
      // - 主题色切换时 Obx 自动重建（外层 build 已在 Obx 外）
      floatingActionButton: Obx(
        () => controller.catalogCategories.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton(
                heroTag: 'home_catalog_fab',
                onPressed: () => _showCatalogSheet(
                  context,
                  AppTheme.colorsOf(context),
                ),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 4,
                child: const Icon(PhosphorIconsRegular.list),
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

  /// 卷帘式目录 BottomSheet
  ///
  /// 展示首页"目录"区块所有分类（含视频数量），
  /// 点击分类项关闭 BottomSheet 并跳转到独立分类页。
  ///
  /// 设计：
  /// - 圆角顶部 + drag handle（MD3 BottomSheet 风格）
  /// - 标题栏：左侧"目录"标题 + 右侧"取消"按钮
  /// - 列表项：左侧分类名 + 右侧视频数量（如 "4827"）
  /// - 点击项关闭 BottomSheet 并 Get.toNamed('/category')
  void _showCatalogSheet(BuildContext context, ThemeColors colors) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.spaceSm),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceLg,
                  DesignTokens.spaceMd,
                  DesignTokens.spaceMd,
                  DesignTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.squaresFour,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Text(
                      '目录',
                      style: TextStyle(
                        fontSize: DesignTokens.textH2,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSm,
                          vertical: DesignTokens.spaceXs,
                        ),
                        child: Icon(
                          PhosphorIconsRegular.x,
                          size: 20,
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
              ),
              // 分类列表（含 count 视频数量）
              //
              // 卷帘菜单仅展示"目录"区块分类（isCatalog=true），
              // 不包含顶部导航菜单中独有的分类。
              Flexible(
                child: Obx(() {
                  final cats = controller.catalogCategories;
                  if (cats.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(DesignTokens.spaceXl),
                      child: Center(
                        child: Text(
                          '暂无分类',
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: DesignTokens.textBody,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceSm,
                    ),
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: DesignTokens.spaceLg,
                      endIndent: DesignTokens.spaceLg,
                      color: colors.border.withOpacity(0.5),
                    ),
                    itemBuilder: (_, i) {
                      final c = cats[i];
                      return _CatalogListItem(
                        category: c,
                        colors: colors,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          // 跳转到独立分类页（保留完整分页能力）
                          Get.toNamed('/category', arguments: c.id);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
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
  /// - 横向滚动 Tab 列表（含"推荐" + nav 分类）
  /// - 选中态：primary 背景 + onPrimary 文字 + elevation1 阴影
  /// - 未选中态：surface 背景 + onSurfaceMuted 文字 + outline 边框
  /// - pill 形状（radiusPill = 999）
  /// - 主题色切换时通过 Obx 自动重建
  ///
  /// **不包含"目录"区块分类**（用户需求）：
  /// Tab 列表只展示导航菜单中独有的分类（isCatalog=false），
  /// 目录分类通过右下角卷帘菜单访问。
  Widget _buildCategoryTabs(colors) {
    return SizedBox(
      height: 40,
      child: Obx(() {
        final selectedId = controller.selectedCategoryId.value;
        // Tab 列表：推荐 + nav 分类（不含目录区块分类）
        final tabs = <_CategoryTab>[
          const _CategoryTab(id: null, name: '推荐'),
          ...controller.navCategories.map(
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

  /// "推荐"Tab 内容：所有 nav 分类 section（保留原布局）
  ///
  /// **不包含"目录"区块分类**（用户需求）：
  /// 推荐 sections 只展示导航菜单中独有的分类（isCatalog=false），
  /// 目录分类通过右下角卷帘菜单跳转独立分类页查看。
  Widget _buildRecommendView(colors) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.spaceSm,
      ),
      children: [
        ...controller.navCategories.map(
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
            // 16:9 封面 + 2 行标题 + 元信息行 = 卡片高 ≈ 卡片宽
            // 旧值 0.65 会让文字区下方留白约 100px，列表底部空一大块
            childAspectRatio: 1.0,
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
        childAspectRatio: 1.0,
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

/// 目录卷帘菜单列表项
///
/// 展示分类名 + 视频数量（来自站点 .stui-pannel__menu 的 count）
/// 设计：
/// - 左侧分类名（onSurface 主色，textBody 字号）
/// - 右侧视频数量 chip（surfaceVariant 背景，onSurfaceMuted 文字）
/// - 点击态：InkWell ripple effect
/// - 高度 56（MD3 ListItem 标准）
class _CatalogListItem extends StatelessWidget {
  final Category category;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _CatalogListItem({
    required this.category,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceLg,
          vertical: DesignTokens.spaceMd,
        ),
        child: Row(
          children: [
            // 左侧分类名
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: DesignTokens.textBody,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ),
            // 右侧视频数量 chip
            if (category.count > 0) ...[
              const SizedBox(width: DesignTokens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                ),
                child: Text(
                  _formatCount(category.count),
                  style: TextStyle(
                    fontSize: DesignTokens.textCaption,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(width: DesignTokens.spaceXs),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: colors.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化视频数量
  ///
  /// - < 10000: 原样显示（如 4827）
  /// - >= 10000: 显示为 7.7w（节省横向空间）
  static String _formatCount(int count) {
    if (count < 10000) return count.toString();
    final w = count / 10000;
    return '${w.toStringAsFixed(1)}w';
  }
}
