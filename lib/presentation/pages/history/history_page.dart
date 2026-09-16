import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/core/utils/number_formatter.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/presentation/controllers/history_controller.dart';
import 'package:yellow_depot/presentation/routes/app_pages.dart';
import 'package:yellow_depot/presentation/widgets/video_card.dart';

/// 播放历史页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - AppBar "播放历史" + 右侧 "清空" 按钮（弹确认对话框）
/// - 列表 CustomScrollView，按观看日期分组（今天 / 昨天 / 前天 / 具体日期）
/// - 分组头吸顶（SliverPersistentHeader pinned）：滚动后当前日期的
///   分组头固定在列表顶部，随时可收拢 / 展开，无需回滚
/// - 分组头：日期标签 + 条数 + 收拢/展开箭头（点击整行切换）
/// - 每条：左侧 80x60 圆角 8 封面 + 右侧标题/时间/进度条
/// - 进度条显示 PlayHistory.progress
/// - Dismissible 滑动删除单条
/// - 空状态 EmptyView
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryController controller;

  /// 已收拢的日期分组（dateKey 形如 "2026-09-16"）
  ///
  /// 默认全部分组展开；点击分组头切换收拢 / 展开。
  /// 状态在页面存续期内保持（数据刷新 / 删除单条 / 重新加载不重置）。
  final Set<String> _collapsedDates = <String>{};

  @override
  void initState() {
    super.initState();
    controller = Get.find<HistoryController>();
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
        final errMsg = controller.errorMessage.value;
        if (errMsg.isNotEmpty && controller.histories.isEmpty) {
          return ErrorView(message: errMsg, onRetry: controller.loadHistory);
        }
        if (controller.histories.isEmpty) {
          return const EmptyView(
            icon: PhosphorIconsRegular.clock,
            title: '暂无历史',
            subtitle: '看完的视频会在这里继续',
          );
        }
        // 按观看日期分组（histories 已按 updatedAt 倒序，分组天然从新到旧）
        final groups = _buildGroups(controller.histories);
        // 吸顶分组列表：分组头 SliverPersistentHeader(pinned) 固定，
        // 滚动离开视口后仍贴在列表顶部（直到被下一分组头顶替），
        // 无需回滚即可收拢 / 展开；收拢分组不渲染条目 sliver，保持惰性构建
        return CustomScrollView(
          slivers: [
            for (final g in groups) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _GroupHeaderDelegate(
                  group: g,
                  collapsed: _collapsedDates.contains(g.key),
                  onToggle: () => _toggleGroup(g.key),
                  colors: colors,
                ),
              ),
              if (!_collapsedDates.contains(g.key))
                SliverList.builder(
                  itemCount: g.items.length,
                  itemBuilder: (context, i) {
                    final h = g.items[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignTokens.spaceMd,
                        0,
                        DesignTokens.spaceMd,
                        DesignTokens.spaceSm,
                      ),
                      child: Dismissible(
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
              onDismissed: (_) async {
                try {
                  await controller.deleteHistory(h.videoId);
                  Get.snackbar(
                    '已删除',
                    '「${h.title}」的历史记录已移除',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                } catch (e) {
                  Get.snackbar(
                    '删除失败',
                    e.toString(),
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                }
              },
              child: _HistoryItem(
                history: h,
                onTap: () => Get.toNamed(
                  AppPages.detail,
                  arguments: {
                    'videoId': h.videoId,
                    'coverUrl': h.coverUrl,
                    'title': h.title,
                  },
                ),
              ),
                      ),
                    );
                  },
                ),
            ],
            // 列表尾部留白
            const SliverPadding(
              padding: EdgeInsets.only(bottom: DesignTokens.spaceMd),
            ),
          ],
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
            onPressed: () async {
              Get.back();
              try {
                await controller.clearAll();
              } catch (e) {
                Get.snackbar(
                  '清空失败',
                  e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              }
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

  /// 按观看日期（天）分组
  ///
  /// [histories] 已按 updatedAt 倒序（DAO ORDER BY updatedAt DESC），
  /// 因此分组出现顺序天然从新到旧，组内条目保持倒序。
  /// 同一天的多条记录归入同一组，组随数据变化自动增删。
  List<_DateGroup> _buildGroups(List<PlayHistory> histories) {
    final now = DateTime.now();
    final groups = <_DateGroup>[];
    final groupIndexByKey = <String, int>{};
    for (final h in histories) {
      final dt = _normalizeTime(h.updatedAt);
      final date = DateTime(dt.year, dt.month, dt.day);
      final key = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      var idx = groupIndexByKey[key];
      if (idx == null) {
        idx = groups.length;
        groupIndexByKey[key] = idx;
        groups.add(_DateGroup(key, _dateLabel(date, now)));
      }
      // 创建新组时也必须加入当前记录，否则每组会漏掉第一条
      //（单条记录的日期会显示成"0 条"空组）
      groups[idx].items.add(h);
    }
    return groups;
  }

  /// 切换分组收拢 / 展开
  void _toggleGroup(String dateKey) {
    setState(() {
      // remove 返回 false 表示原本未收拢 → 加入收拢集合
      if (!_collapsedDates.remove(dateKey)) {
        _collapsedDates.add(dateKey);
      }
    });
  }

  /// 时间戳转 DateTime（兼容秒级 / 毫秒级，与条目 _formatTime 一致）
  DateTime _normalizeTime(int timestamp) {
    if (timestamp <= 0) return DateTime.fromMillisecondsSinceEpoch(0);
    final ms = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 日期标签：今天 / 昨天 / 前天 / M月d日（往年带年份）
  String _dateLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = today.difference(date).inDays;
    if (diffDays == 0) return '今天';
    if (diffDays == 1) return '昨天';
    if (diffDays == 2) return '前天';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
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
                          )
                        else if (history.progress > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              '已观看${(history.progress * 100).clamp(0, 100).round()}%',
                              style: TextStyle(
                                fontSize: DesignTokens.textLabel,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
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
        NumberFormatter.formatCount(h.playCount),
        colors,
      ));
    }
    if (h.likeCount > 0) {
      items.add(_metaItem(
        PhosphorIconsFill.heart,
        NumberFormatter.formatCount(h.likeCount),
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
}

/// 按观看日期（天）划分的历史分组
class _DateGroup {
  /// 唯一标识（yyyy-MM-dd，用作收拢状态 [_HistoryPageState._collapsedDates] 的 key）
  final String key;

  /// 展示标签（今天 / 昨天 / 前天 / 9月10日 / 2025年12月31日）
  final String label;

  /// 组内条目（保持 updatedAt 倒序）
  final List<PlayHistory> items = <PlayHistory>[];

  _DateGroup(this.key, this.label);
}

/// 吸顶分组头 delegate
///
/// 配合 `SliverPersistentHeader(pinned: true)` 实现吸顶：
/// 分组头随内容滚出视口后固定在列表顶部，直到被下一分组头顶替，
/// 用户在任意滚动位置都能直接收拢 / 展开当前日期分组。
///
/// 视觉：主题色竖条 + 日期标签 + 条数 + 收拢/展开箭头（点击整行切换，
/// 箭头随状态旋转 -90°）。吸顶与后随内容重叠时（[overlapsContent]）
/// 底部显示细分割线增强层级感。
class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 分组头固定高度
  static const double headerHeight = 40;

  final _DateGroup group;

  /// 是否收拢
  final bool collapsed;

  /// 点击整行切换收拢 / 展开
  final VoidCallback onToggle;

  final ThemeColors colors;

  _GroupHeaderDelegate({
    required this.group,
    required this.collapsed,
    required this.onToggle,
    required this.colors,
  });

  @override
  double get minExtent => headerHeight;

  @override
  double get maxExtent => headerHeight;

  @override
  bool shouldRebuild(covariant _GroupHeaderDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: colors.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 0.5,
              color: overlapsContent ? colors.border : Colors.transparent,
            ),
          ),
        ),
        child: InkWell(
          onTap: onToggle,
          child: SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
              ),
              child: Row(
                children: [
                  // 主题色竖条装饰
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusPill,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Text(
                    group.label,
                    style: TextStyle(
                      fontSize: DesignTokens.textBody,
                      fontWeight: FontWeight.w600,
                      color: colors.onBackground,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Text(
                    '${group.items.length} 条',
                    style: TextStyle(
                      fontSize: DesignTokens.textCaption,
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      PhosphorIconsRegular.caretDown,
                      size: 16,
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
