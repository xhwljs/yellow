import 'package:flutter/material.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

/// 元信息行（图标 + 文本，多项以 `·` 连接，强制单行）。
///
/// 用于视频卡片 / 历史记录项的「时长 · 播放数 · 收藏数 · 更新时间」展示。
///
/// 设计：
/// - 各项以分隔点 `·` 连接，调用方按需传入，缺失项不传入即可自动跳过
/// - 图标 + 数字紧凑展示（间距 2px），使用 `onSurfaceMuted` 颜色
/// - 最后一项 `Expanded` + `ellipsis` 兜底，极端长内容也不会溢出
/// - `items` 为空时返回 `SizedBox.shrink()`
class MetaRow extends StatelessWidget {
  final List<MetaItem> items;

  const MetaRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = AppTheme.colorsOf(context);

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
      final isLast = i == items.length - 1;
      children.add(
        isLast
            ? Expanded(child: _MetaItemWidget(item: items[i]))
            : _MetaItemWidget(item: items[i]),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

/// 元信息单项数据（图标 + 文本）。
@immutable
class MetaItem {
  final IconData icon;
  final String text;

  const MetaItem({required this.icon, required this.text});
}

class _MetaItemWidget extends StatelessWidget {
  final MetaItem item;

  const _MetaItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          size: 11,
          color: colors.onSurfaceMuted,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            item.text,
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
