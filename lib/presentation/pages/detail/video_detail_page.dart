import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_presets.dart';
import 'package:videohub/data/models/video_detail.dart';
import 'package:videohub/presentation/controllers/video_detail_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

/// 视频详情页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - CustomScrollView + SliverAppBar（顶部内联播放器）
/// - 标题、简介、相关推荐
/// - 浮动 "全屏播放" FAB，颜色用 colors.primary
/// - 收藏 IconButton：已收藏 solid / 未收藏 outline
///
/// 顶部 SliverAppBar 区域集成了 video_player + chewie 内联播放器：
/// - 初始态：封面略缩图 + 中央播放按钮（chewie 内置略缩图能力）
/// - 加载态：封面 + Loading 圈
/// - 播放态：chewie 播放器（自带播放/暂停/进度/全屏/倍速按钮）
/// - 错误态：封面 + 错误图标 + 重试按钮
///
/// 现有功能保持不变：FAB 全屏跳转 / 收藏 / 相关推荐 / 标题简介。
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
          icon: const Icon(PhosphorIconsFill.play),
          label: const Text(
            '全屏播放',
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
            background: _InlinePlayerArea(
              controller: controller,
              colors: colors,
            ),
          ),
          actions: [
            Obx(() {
              final favorited = controller.isFavorited.value;
              return IconButton(
                icon: Icon(
                  favorited
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
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
          icon: PhosphorIconsRegular.play,
          text: '${detail.video.playCount} 次播放',
          colors: colors,
        ),
        _MetaChip(
          icon: PhosphorIconsRegular.heart,
          text: '${detail.video.likeCount} 喜欢',
          colors: colors,
        ),
        if (detail.video.duration.isNotEmpty)
          _MetaChip(
            icon: PhosphorIconsRegular.timer,
            text: detail.video.duration,
            colors: colors,
          ),
        if (detail.video.updateTime.isNotEmpty)
          _MetaChip(
            icon: PhosphorIconsRegular.calendar,
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
    );
  }
}

/// 元信息 Chip
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeColors colors;

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

/// 详情页顶部内联播放器区域
///
/// 集成 video_player + chewie，使用 chewie 自带控件（播放/暂停/进度/全屏/倍速）。
///
/// 状态机：
/// - 初始态（_inlineStarted == false）：封面 + 中央播放按钮
/// - 加载态（inlineLoading == true）：封面 + 半透明遮罩 + Loading 圈
/// - 播放态（inlineChewieController != null）：chewie 播放器
/// - 错误态（inlineErrorMessage != ''）：封面 + 错误图标 + 重试按钮
///
/// 用户点击中央播放按钮 → 调用 [VideoDetailController.startInlinePlay]。
/// 该方法会调用 [UrlDecryptor.decryptPlayUrl] 解密播放地址，然后初始化
/// video_player + chewie，autoPlay 自动播放。
class _InlinePlayerArea extends StatelessWidget {
  final VideoDetailController controller;
  final ThemeColors colors;

  const _InlinePlayerArea({
    required this.controller,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final videoController = controller.inlineVideoController.value;
      final chewieController = controller.inlineChewieController.value;
      final isLoading = controller.inlineLoading.value;
      final errorMessage = controller.inlineErrorMessage.value;

      // 错误态：封面 + 重试按钮
      if (errorMessage.isNotEmpty) {
        return _buildThumbnail(
          coverUrl: controller.effectiveCoverUrl,
          overlay: _ErrorOverlay(
            message: errorMessage,
            onRetry: controller.retryInlinePlay,
            colors: colors,
          ),
        );
      }

      // 加载态：封面 + Loading 圈
      if (isLoading) {
        return _buildThumbnail(
          coverUrl: controller.effectiveCoverUrl,
          overlay: _LoadingOverlay(colors: colors),
        );
      }

      // 播放态：chewie 播放器
      if (videoController != null &&
          chewieController != null &&
          videoController.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: Chewie(controller: chewieController),
        );
      }

      // 初始态：封面 + 中央播放按钮
      return _buildThumbnail(
        coverUrl: controller.effectiveCoverUrl,
        overlay: _PlayButtonOverlay(
          onTap: controller.startInlinePlay,
          colors: colors,
        ),
      );
    });
  }

  /// 构建封面略缩图（含底部渐变遮罩 + 叠加层）
  ///
  /// 与原详情页 SliverAppBar 背景视觉一致：
  /// - CachedNetworkImage 全屏 cover
  /// - 顶部 30% 黑色渐变（提升返回按钮可见度）
  /// - 中央叠加 [overlay] 内容（播放按钮 / loading / 错误）
  Widget _buildThumbnail({
    required String coverUrl,
    required Widget overlay,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面
        if (coverUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: DesignTokens.colorSkeleton),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black,
              child: Center(
                child: Icon(
                  PhosphorIconsRegular.filmSlate,
                  size: 48,
                  color: colors.onSurfaceMuted,
                ),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Icon(
                PhosphorIconsRegular.filmSlate,
                size: 48,
                color: colors.onSurfaceMuted,
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
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        // 叠加层（播放按钮 / loading / 错误）
        overlay,
      ],
    );
  }
}

/// 中央播放按钮叠加层（初始态）
///
/// 大号圆形按钮，点击触发 [VideoDetailController.startInlinePlay]。
/// 半透明黑色边框 + 主题色填充，符合 Material Design FilledButton 风格。
class _PlayButtonOverlay extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeColors colors;

  const _PlayButtonOverlay({
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.9),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              PhosphorIconsFill.play,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 加载叠加层（解密 + 视频初始化阶段）
class _LoadingOverlay extends StatelessWidget {
  final ThemeColors colors;
  const _LoadingOverlay({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: colors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          const Text(
            '正在解析播放地址...',
            style: TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textCaption,
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误叠加层（含重试按钮）
class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeColors colors;

  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            color: colors.destructive,
            size: 40,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textCaption,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
