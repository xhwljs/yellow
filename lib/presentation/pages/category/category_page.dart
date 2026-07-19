import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/presentation/controllers/category_controller.dart';
import 'package:videohub/presentation/controllers/home_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

/// 分类页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 2 列 GridView，spacing 12，crossAxisChildAspectRatio 0.65
/// - 滚动到底部自动 loadMore
/// - isLoadingMore 时底部显示 CircularProgressIndicator
/// - 下拉刷新 / 错误 / 空数据三态
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final CategoryController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CategoryController>();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 100) {
      if (!_controller.isLoadingMore.value && _controller.hasMore.value) {
        _controller.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveCategoryName() {
    final categoryId = _controller.categoryId;
    try {
      final homeController = Get.find<HomeController>();
      for (final c in homeController.categories) {
        if (c.id == categoryId) return c.name;
      }
    } catch (_) {}
    return '分类';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: Get.back,
          tooltip: '返回',
        ),
        title: Text(
          _resolveCategoryName(),
          style: TextStyle(
            color: colors.onBackground,
            fontSize: DesignTokens.textH1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.videos.isEmpty) {
          return _buildSkeletonGrid();
        }
        if (_controller.errorMessage.value.isNotEmpty &&
            _controller.videos.isEmpty) {
          return ErrorView(
            message: _controller.errorMessage.value,
            onRetry: _controller.refresh,
          );
        }
        if (_controller.videos.isEmpty) {
          return EmptyView(
            icon: PhosphorIconsRegular.filmSlate,
            title: '暂无视频',
            subtitle: '该分类下还没有内容',
            onAction: _controller.refresh,
            actionLabel: '刷新',
          );
        }
        return RefreshIndicator(
          color: colors.primary,
          onRefresh: _controller.refresh,
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: DesignTokens.videoGridCrossAxisCount,
              mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
              crossAxisSpacing: DesignTokens.videoGridSpacing,
              childAspectRatio: 0.65,
            ),
            itemCount: _controller.videos.length +
                (_controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _controller.videos.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLg),
                    child: CircularProgressIndicator(color: colors.primary),
                  ),
                );
              }
              final v = _controller.videos[i];
              return VideoCard(
                video: v,
                onTap: () => Get.toNamed('/detail', arguments: v.id),
              );
            },
          ),
        );
      }),
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
        childAspectRatio: 0.65,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const VideoCardSkeleton(),
    );
  }
}
