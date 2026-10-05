import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yellow_depot/core/services/watched_service.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/core/utils/number_formatter.dart';
import 'package:yellow_depot/data/models/video.dart';

/// 视频卡片（Bento Grid 风格）
///
/// 展示内容（自上而下）：
/// - 封面（16:9）+ 角标（时长 / 收藏 / 已看 / 时间）+ 进度条
/// - 标题（最多 2 行）
/// - 元信息行（播放次数 · 收藏次数 · 更新时间）
///
/// 角标体系（统一玻璃拟态胶囊，见 [_GlassBadge]）：
/// - 右下：时长（深色玻璃底 + 时钟图标 + 白字）
/// - 右上：已看（深色玻璃底 + 主色勾选图标与文字）
/// - 左上：收藏（主色圆形实底）或时间角标 [timeLabel]
///   （互斥：有收藏时优先收藏，时间角标隐藏）
///
/// 元信息行规则：
/// - 三项都有 → eye count · heart count · clock time
/// - 部分缺失 → 自动跳过空项，以分隔点连接
/// - 全部缺失 → 不渲染该行，节省高度
class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  final bool isFavorited;
  final double? progress;

  /// 封面左上角的时间角标文案（如"3小时前"）
  ///
  /// 供"最新"Tab 展示相对发布时间；为 null 时不渲染。
  final String? timeLabel;

  /// 时间角标是否高亮（如 24 小时内上架）
  ///
  /// true → 主色实底 + 白字（与收藏角标同视觉层级）；
  /// false → 深色玻璃底 + 白字（普通角标层级）。
  final bool highlightTimeLabel;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.isFavorited = false,
    this.progress,
    this.timeLabel,
    this.highlightTimeLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    // 已看角标依赖 WatchedService（permanent 注册）；
    // 测试 / 预览环境未注册时静默降级（不渲染角标）
    final hasWatchedService = Get.isRegistered<WatchedService>();

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
                    errorWidget: (_, __, ___) => const _CoverPlaceholder(
                      icon: PhosphorIconsRegular.filmSlate,
                    ),
                  ),
                  // 时长 badge（右下：深色玻璃胶囊 + 时钟图标）
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: DesignTokens.spaceSm,
                      bottom: DesignTokens.spaceSm,
                      child: _GlassBadge(
                        icon: PhosphorIconsRegular.clock,
                        text: video.duration,
                      ),
                    ),
                  // 时间角标（左上：最新页相对发布时间；有收藏时让位隐藏）
                  if (timeLabel != null && timeLabel!.isNotEmpty && !isFavorited)
                    Positioned(
                      left: DesignTokens.spaceSm,
                      top: DesignTokens.spaceSm,
                      child: _GlassBadge(
                        text: timeLabel!,
                        background: highlightTimeLabel
                            ? colors.primary
                            : DesignTokens.colorBadgeScrim,
                        textColor: highlightTimeLabel
                            ? colors.onPrimary
                            : Colors.white,
                        iconColor: highlightTimeLabel
                            ? colors.onPrimary
                            : Colors.white70,
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
                  // 已看角标（右上角，基于播放历史响应式刷新）
                  if (hasWatchedService)
                    Positioned(
                      right: DesignTokens.spaceSm,
                      top: DesignTokens.spaceSm,
                      child: Obx(() {
                        final ws = Get.find<WatchedService>();
                        // 读 RxInt 确保 Obx 依赖注册（RxSet.contains 不保证）
                        final watched = ws.watchedCount.value > 0 &&
                            ws.isWatched(video.id);
                        if (!watched) return const SizedBox.shrink();
                        return _GlassBadge(
                          icon: PhosphorIconsFill.checkCircle,
                          text: '已看',
                          textColor: colors.primary,
                          iconColor: colors.primary,
                        );
                      }),
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
            // 标题 + 元信息
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceSm,
                DesignTokens.spaceSm,
                DesignTokens.spaceSm,
                DesignTokens.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  _buildMetaRow(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 元信息行：播放次数 · 收藏次数 · 更新时间
  ///
  /// 设计：
  /// - **强制单行**（用 Row 替代 Wrap），避免换行导致卡片高度溢出
  /// - 三项以分隔点 "·" 连接，缺失项自动跳过
  /// - 图标 + 数字紧凑展示（间距 2px），使用 onSurfaceMuted 颜色
  /// - 最后一项用 Expanded + ellipsis 兜底，极端长内容也不会溢出
  /// - 全部缺失时不渲染（返回 SizedBox.shrink），节省卡片高度
  Widget _buildMetaRow(ThemeColors colors) {
    final items = <Widget>[];

    if (video.playCount > 0) {
      items.add(_MetaItem(
        icon: PhosphorIconsRegular.eye,
        text: NumberFormatter.formatCount(video.playCount),
      ));
    }
    if (video.likeCount > 0) {
      items.add(_MetaItem(
        icon: PhosphorIconsFill.heart,
        text: NumberFormatter.formatCount(video.likeCount),
      ));
    }
    if (video.updateTime.isNotEmpty) {
      items.add(_MetaItem(
        icon: PhosphorIconsRegular.calendar,
        text: video.updateTime,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    // 构建单行：item0 · item1 · item2 ...
    // 最后一项包 Expanded+ellipsis 兜底（理论上数据很短不会触发）
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurfaceMuted,
            ),
          ),
        ));
      }
      if (i == items.length - 1) {
        // 最后一项 Expanded 兜底防止极端溢出
        children.add(Expanded(child: items[i]));
      } else {
        children.add(items[i]);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.spaceXs),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// 元信息单项（图标 + 文本）
///
/// 强制单行：Text overflow ellipsis 防止极端长内容溢出 Row
class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 11,
          color: colors.onSurfaceMuted,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurfaceMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// 玻璃拟态角标（胶囊形）
///
/// 深色半透明底 + 细白描边模拟玻璃质感（静态样式，
/// 不用 BackdropFilter，保证长列表滚动性能）。
///
/// 设计约束（ui-ux-pro-max 技能检索结论）：
/// - 单行不换行（Compact Label Overflow, Severity: High）
/// - 深色 scrim 上白字对比度 ≥4.5:1
/// - 图标 10px 与 textLabel(11) 字号层级匹配
class _GlassBadge extends StatelessWidget {
  final String text;

  /// 前置图标（可选，与其他角标统一线性/填充语言）
  final IconData? icon;

  final Color textColor;
  final Color? iconColor;

  /// 底色（默认深色玻璃 scrim，可覆写为主题色实底）
  final Color background;

  const _GlassBadge({
    required this.text,
    this.icon,
    this.textColor = Colors.white,
    this.iconColor,
    this.background = DesignTokens.colorBadgeScrim,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? textColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(
          color: background == DesignTokens.colorBadgeScrim
              ? Colors.white24
              : Colors.transparent,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: resolvedIconColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: DesignTokens.textLabel,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
        ],
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
