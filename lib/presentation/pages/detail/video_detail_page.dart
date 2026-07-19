import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/data/models/video_detail.dart';
import 'package:videohub/presentation/controllers/video_detail_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

/// 视频详情页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - CustomScrollView + SliverAppBar（封面背景 + 标题）
/// - 视频封面 16:9 CachedNetworkImage
/// - 标题、简介、相关推荐
/// - 浮动 "播放" FAB，颜色用 colors.primary
/// - 收藏 IconButton：已收藏 solid / 未收藏 outline
class VideoDetailPage extends GetView<VideoDetailController> {
  const VideoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Obx(() {
        if (controller.isLoading.value && controller.detail.value == null) {
          return const LoadingView(message: '加载中...');
        }
        if (controller.errorMessage.value.isNotEmpty &&
            controller.detail.value == null) {
          return ErrorView(
            message: controller.errorMessage.value,
            onRetry: controller.loadDetail,
          );
        }
        final detail = controller.detail.value;
        if (detail == null) {
          return const LoadingView(message: '加载中...');
        }
        return _buildContent(context, colors, detail);
      }),
      floatingActionButton: Obx(() {
        if (controller.detail.value == null) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: controller.goToPlayer,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 4,
          icon: Icon(PhosphorIconsFill.play()),
          label: const Text(
            '播放',
            style: TextStyle(
              fontSize: DesignTokens.textBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context, colors, VideoDetail detail) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: colors.surface,
          foregroundColor: colors.onBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: detail.video.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: DesignTokens.colorSkeleton),
                  errorWidget: (_, __, ___) => Container(
                    color: DesignTokens.colorSkeleton,
                    child: Center(
                      child: Icon(
                        PhosphorIconsRegular.filmSlate(),
                        size: 48,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                // 底部渐变遮罩（提升返回按钮可见度）
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.4, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Obx(() {
              final favorited = controller.isFavorited.value;
              return IconButton(
                icon: Icon(
                  favorited
                      ? PhosphorIconsFill.heart()
                      : PhosphorIconsRegular.heart(),
                  color: favorited ? colors.primary : colors.onBackground,
                  size: 24,
                ),
                onPressed: controller.toggleFavorite,
                tooltip: favorited ? '取消收藏' : '收藏',
              );
            }),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(colors, detail),
                const SizedBox(height: DesignTokens.spaceLg),
                _buildMetaRow(colors, detail),
                const SizedBox(height: DesignTokens.spaceXl),
                _buildDescription(colors, detail),
                const SizedBox(height: DesignTokens.spaceXl),
                if (detail.relatedVideos.isNotEmpty)
                  _buildRelatedVideos(colors, detail),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(colors, VideoDetail detail) {
    return Text(
      detail.video.title,
      style: TextStyle(
        fontSize: DesignTokens.textH1,
        fontWeight: FontWeight.w700,
        color: colors.onBackground,
        height: 1.3,
      ),
    );
  }

  Widget _buildMetaRow(colors, VideoDetail detail) {
    return Wrap(
      spacing: DesignTokens.spaceLg,
      runSpacing: DesignTokens.spaceSm,
      children: [
        _MetaChip(
          icon: PhosphorIconsRegular.play(),
          text: '${detail.video.playCount} 次播放',
          colors: colors,
        ),
        _MetaChip(
          icon: PhosphorIconsRegular.heart(),
          text: '${detail.video.likeCount} 喜欢',
          colors: colors,
        ),
        if (detail.video.duration.isNotEmpty)
          _MetaChip(
            icon: PhosphorIconsRegular.timer(),
            text: detail.video.duration,
            colors: colors,
          ),
        if (detail.video.updateTime.isNotEmpty)
          _MetaChip(
            icon: PhosphorIconsRegular.calendar(),
            text: detail.video.updateTime,
            colors: colors,
          ),
      ],
    );
  }

  Widget _buildDescription(colors, VideoDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '简介',
          style: TextStyle(
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
            color: colors.onBackground,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Text(
          detail.description.isEmpty ? '暂无简介' : detail.description,
          style: TextStyle(
            fontSize: DesignTokens.textBody,
            color: colors.onSurfaceMuted,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedVideos(colors, VideoDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '相关推荐',
          style: TextStyle(
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
            color: colors.onBackground,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: detail.relatedVideos.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: DesignTokens.spaceMd),
            itemBuilder: (_, i) {
              final v = detail.relatedVideos[i];
              return SizedBox(
                width: 160,
                child: VideoCard(
                  video: v,
                  onTap: () => Get.toNamed('/detail', arguments: v.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 元信息 Chip
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final colors;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceMuted),
        const SizedBox(width: DesignTokens.spaceXs),
        Text(
          text,
          style: TextStyle(
            fontSize: DesignTokens.textCaption,
            color: colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
