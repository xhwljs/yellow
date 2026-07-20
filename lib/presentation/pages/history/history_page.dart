import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/presentation/controllers/history_controller.dart';
import 'package:yellow_depot/presentation/widgets/video_card.dart';

/// 播放历史页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - AppBar "播放历史" + 右侧 "清空" 按钮（弹确认对话框）
/// - 列表 ListView.separated
/// - 每条：左侧 80x60 圆角 8 封面 + 右侧标题/时间/进度条
/// - 进度条显示 PlayHistory.progress
/// - Dismissible 滑动删除单条
/// - 空状态 EmptyView
class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

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
          '播放历史',
          style: TextStyle(
            color: colors.onBackground,
            fontSize: DesignTokens.textH1,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Obx(
            () => controller.histories.isNotEmpty
                ? TextButton(
                    onPressed: _confirmClearAll,
                    child: Text(
                      '清空',
                      style: TextStyle(
                        color: colors.destructive,
                        fontSize: DesignTokens.textBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.histories.isEmpty) {
          return const LoadingView(message: '加载中...');
        }
        if (controller.histories.isEmpty) {
          return const EmptyView(
            icon: PhosphorIconsRegular.clock,
            title: '暂无历史',
            subtitle: '看完的视频会在这里继续',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          itemCount: controller.histories.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: DesignTokens.spaceSm),
          itemBuilder: (_, i) {
            final h = controller.histories[i];
            return Dismissible(
              key: ValueKey('history_${h.videoId}'),
              direction: DismissDirection.startToEnd,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(
                  left: DesignTokens.spaceLg,
                ),
                decoration: BoxDecoration(
                  color: colors.destructive,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Icon(
                  PhosphorIconsRegular.trash,
                  color: colors.surface,
                  size: 24,
                ),
              ),
              onDismissed: (_) {
                controller.deleteHistory(h.videoId);
                Get.snackbar(
                  '已删除',
                  '「${h.title}」的历史记录已移除',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
              child: _HistoryItem(
                history: h,
                onTap: () => Get.toNamed(
                  '/detail',
                  arguments: {
                    'videoId': h.videoId,
                    'coverUrl': h.coverUrl,
                    'title': h.title,
                  },
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmClearAll() {
    final colors = AppTheme.colorsOf(Get.context!);
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        title: Text(
          '清空历史',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要清空所有播放历史吗？此操作不可撤销。',
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
              controller.clearAll();
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

/// 单条历史项
class _HistoryItem extends StatelessWidget {
  final PlayHistory history;
  final VoidCallback onTap;

  const _HistoryItem({required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Row(
            children: [
              // 左侧封面缩略图 80x60 圆角 8
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: CachedNetworkImage(
                    imageUrl: history.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: DesignTokens.colorSkeleton,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: DesignTokens.colorSkeleton,
                      child: Icon(
                        PhosphorIconsRegular.filmSlate,
                        size: 24,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              // 右侧标题 / 时间 / 进度条
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      history.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.textBody,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.clock,
                          size: 12,
                          color: colors.onSurfaceMuted,
                        ),
                        const SizedBox(width: DesignTokens.spaceXs),
                        Expanded(
                          child: Text(
                            _formatTime(history.updatedAt),
                            style: TextStyle(
                              fontSize: DesignTokens.textCaption,
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                        ),
                        if (history.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              '已看完',
                              style: TextStyle(
                                fontSize: DesignTokens.textLabel,
                                fontWeight: FontWeight.w600,
                                color: colors.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 详情元信息行：时长 · 播放次数 · 收藏次数 · 更新时间
                    // 字段为空时自动跳过，全部为空时不渲染
                    if (_hasMetaInfo(history)) ...[
                      const SizedBox(height: DesignTokens.spaceXs),
                      _buildMetaRow(history, colors),
                    ],
                    const SizedBox(height: DesignTokens.spaceXs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusPill,
                      ),
                      child: LinearProgressIndicator(
                        value: history.progress,
                        minHeight: 3,
                        backgroundColor: colors.border,
                        valueColor: AlwaysStoppedAnimation(colors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return '未知时间';
    // 兼容秒级 / 毫秒级时间戳
    final ms = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// 是否有任何详情元信息可展示
  bool _hasMetaInfo(PlayHistory h) {
    return h.durationText.isNotEmpty ||
        h.playCount > 0 ||
        h.likeCount > 0 ||
        h.updateTime.isNotEmpty;
  }

  /// 详情元信息行：时长 · 播放次数 · 收藏次数 · 更新时间
  ///
  /// 设计：
  /// - **强制单行**（用 Row 替代 Wrap），避免换行导致列表项高度抖动
  /// - 各项以分隔点 "·" 连接，缺失项自动跳过
  /// - 图标 + 文本紧凑展示，使用 onSurfaceMuted 颜色
  /// - 字段从 VideoDao 补全（@ignore），未命中时为空 → 自动跳过
  /// - 最后一项 Expanded+ellipsis 兜底防止极端长内容溢出
  Widget _buildMetaRow(PlayHistory h, ThemeColors colors) {
    final items = <Widget>[];

    if (h.durationText.isNotEmpty) {
      items.add(_metaItem(
        PhosphorIconsRegular.play,
        h.durationText,
        colors,
      ));
    }
    if (h.playCount > 0) {
      items.add(_metaItem(
        PhosphorIconsRegular.eye,
        _formatCount(h.playCount),
        colors,
      ));
    }
    if (h.likeCount > 0) {
      items.add(_metaItem(
        PhosphorIconsFill.heart,
        _formatCount(h.likeCount),
        colors,
      ));
    }
    if (h.updateTime.isNotEmpty) {
      items.add(_metaItem(
        PhosphorIconsRegular.calendar,
        h.updateTime,
        colors,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

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
        children.add(Expanded(child: items[i]));
      } else {
        children.add(items[i]);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _metaItem(IconData icon, String text, ThemeColors colors) {
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

  /// 数字格式化：超过 1万 显示 "1.2万"，超过 1亿 显示 "1.2亿"
  String _formatCount(int n) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(1)}亿';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return n.toString();
  }
}
