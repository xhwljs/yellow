import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/data/models/play_history.dart';
import 'package:videohub/presentation/controllers/history_controller.dart';
import 'package:videohub/presentation/widgets/video_card.dart';

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
          Obx(() => controller.histories.isNotEmpty
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
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.histories.isEmpty) {
          return const LoadingView(message: '加载中...');
        }
        if (controller.histories.isEmpty) {
          return EmptyView(
            icon: PhosphorIconsRegular.clock(),
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
                  PhosphorIconsRegular.trash(),
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
                onTap: () => Get.toNamed('/detail', arguments: h.videoId),
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
                        PhosphorIconsRegular.filmSlate(),
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
                          PhosphorIconsRegular.clock(),
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
                              color: colors.success.withValues(alpha: 0.12),
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
}
