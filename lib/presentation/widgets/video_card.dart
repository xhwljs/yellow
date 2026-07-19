import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/data/models/video.dart';

/// 视频卡片（Bento Grid 风格）
class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  final bool isFavorited;
  final double? progress;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.isFavorited = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            AspectRatio(
              aspectRatio: DesignTokens.videoCardAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _ShimmerBox(),
                    errorWidget: (_, __, ___) => _CoverPlaceholder(
                      icon: PhosphorIconsRegular.filmSlate,
                    ),
                  ),
                  // 时长 badge
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: DesignTokens.spaceSm,
                      bottom: DesignTokens.spaceSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.colorVideoOverlay,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusSm),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.textLabel,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // 收藏角标
                  if (isFavorited)
                    Positioned(
                      left: DesignTokens.spaceSm,
                      top: DesignTokens.spaceSm,
                      child: Container(
                        padding: const EdgeInsets.all(DesignTokens.spaceXs),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIconsFill.heart,
                          color: colors.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                  // 进度条
                  if (progress != null && progress! > 0 && progress! < 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(colors.primary),
                      ),
                    ),
                ],
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignTokens.textBody,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (video.updateTime.isNotEmpty) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      video.updateTime,
                      style: TextStyle(
                        fontSize: DesignTokens.textCaption,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer 占位
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: DesignTokens.colorSkeleton,
      highlightColor: DesignTokens.colorSurface,
      child: Container(
        color: DesignTokens.colorSkeleton,
      ),
    );
  }
}

/// 封面占位图标
class _CoverPlaceholder extends StatelessWidget {
  final IconData icon;
  const _CoverPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.colorSkeleton,
      child: Center(
        child: Icon(
          icon,
          size: 32,
          color: DesignTokens.colorOnSurfaceMuted,
        ),
      ),
    );
  }
}

/// 骨架屏卡片（列表加载占位）
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: DesignTokens.colorSkeleton,
      highlightColor: DesignTokens.colorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: DesignTokens.videoCardAspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.colorSkeleton,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Container(
            height: 12,
            width: double.infinity,
            color: DesignTokens.colorSkeleton,
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Container(
            height: 12,
            width: 100,
            color: DesignTokens.colorSkeleton,
          ),
        ],
      ),
    );
  }
}

/// 加载状态
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          if (message != null) ...[
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              message!,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: DesignTokens.textCaption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 空状态
class EmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = PhosphorIconsRegular.stack,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colors.onSurfaceMuted,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              title,
              style: TextStyle(
                fontSize: DesignTokens.textH2,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: DesignTokens.textCaption,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: DesignTokens.spaceXl),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误状态
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 64,
              color: colors.destructive,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: DesignTokens.textH2,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: DesignTokens.textCaption,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: DesignTokens.spaceXl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
