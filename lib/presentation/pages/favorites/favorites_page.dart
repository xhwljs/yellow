import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/data/models/favorite.dart';
import 'package:videohub/data/models/video.dart';
import 'package:videohub/presentation/controllers/favorites_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

/// 我的收藏页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - AppBar "我的收藏" + count
/// - 2 列 GridView，spacing 12
/// - 视频卡片 isFavorited: true
/// - 长按弹出删除确认对话框
/// - 点击跳转 /detail
/// - 空状态 EmptyView
class FavoritesPage extends GetView<FavoritesController> {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Obx(() => Text(
              '我的收藏 (${controller.favorites.length})',
              style: TextStyle(
                color: colors.onBackground,
                fontSize: DesignTokens.textH1,
                fontWeight: FontWeight.w700,
              ),
            )),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.favorites.isEmpty) {
          return const LoadingView(message: '加载中...');
        }
        if (controller.favorites.isEmpty) {
          return EmptyView(
            icon: PhosphorIconsRegular.heart(),
            title: '暂无收藏',
            subtitle: '去发现喜欢的视频吧',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DesignTokens.videoGridCrossAxisCount,
            mainAxisSpacing: DesignTokens.videoGridMainAxisSpacing,
            crossAxisSpacing: DesignTokens.videoGridSpacing,
            childAspectRatio: 0.65,
          ),
          itemCount: controller.favorites.length,
          itemBuilder: (_, i) {
            final fav = controller.favorites[i];
            final video = _favoriteToVideo(fav);
            return GestureDetector(
              onLongPress: () =>
                  _confirmDelete(fav.videoId, fav.title),
              child: VideoCard(
                video: video,
                isFavorited: true,
                onTap: () =>
                    Get.toNamed('/detail', arguments: fav.videoId),
              ),
            );
          },
        );
      }),
    );
  }

  Video _favoriteToVideo(Favorite fav) {
    return Video(
      id: fav.videoId,
      title: fav.title,
      coverUrl: fav.coverUrl,
      duration: '',
      updateTime: '',
      playCount: 0,
      likeCount: 0,
      categoryId: fav.categoryId,
    );
  }

  void _confirmDelete(String videoId, String title) {
    final colors = AppTheme.colorsOf(Get.context!);
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        title: Text(
          '取消收藏',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要取消收藏「$title」吗？',
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
              controller.removeFavorite(videoId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.destructive,
              foregroundColor: colors.surface,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
