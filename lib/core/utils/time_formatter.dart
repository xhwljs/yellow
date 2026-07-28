import 'package:flutter/material.dart';

/// 时间格式化工具
///
/// 统一全 App 的时间展示规则，避免各页面重复实现导致行为不一致。
class TimeFormatter {
  TimeFormatter._();

  /// 格式化为相对时间（用于列表项紧凑展示）。
  ///
  /// - < 1 分钟：`刚刚`
  /// - < 1 小时：`N 分钟前`
  /// - < 1 天：`N 小时前`
  /// - < 7 天：`N 天前`
  /// - 否则：`YYYY-MM-DD`
  ///
  /// [timestamp] 支持秒级或毫秒级时间戳（自动识别）。
  String formatRelativeTime(int timestamp) {
    if (timestamp <= 0) return '未知时间';
    final dt = _toDateTime(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return formatDate(dt);
  }

  /// 格式化为绝对日期 `YYYY-MM-DD`。
  String formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// 把时间戳转 DateTime，自动兼容秒级 / 毫秒级。
  DateTime _toDateTime(int timestamp) {
    // > 1e12 判定为毫秒级（Unix 秒在 2001 年才到 1e9，毫秒在 2001 年到 1e12）
    final ms = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
