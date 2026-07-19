import 'package:flutter/material.dart';

/// 主题预设 — 5 套可切换主题色
///
/// 严格遵循 design-system/videohub/MASTER.md §3.2
/// 所有主题使用同一浅色背景（#F5F5F7），仅切换 primary/secondary/accent 三个语义令牌。
enum ThemePreset {
  pink(
    id: 'pink',
    name: '热情粉',
    primaryColor: Color(0xFFEC4899),
    secondaryColor: Color(0xFFDB2777),
    accentColor: Color(0xFF2563EB),
    description: '娱乐 / 视频',
  ),
  red(
    id: 'red',
    name: '资讯红',
    primaryColor: Color(0xFFDC2626),
    secondaryColor: Color(0xFFEF4444),
    accentColor: Color(0xFF1E40AF),
    description: '资讯 / 紧凑感',
  ),
  blue(
    id: 'blue',
    name: '专业蓝',
    primaryColor: Color(0xFF3B82F6),
    secondaryColor: Color(0xFF2563EB),
    accentColor: Color(0xFFF59E0B),
    description: '工具 / 专业',
  ),
  purple(
    id: 'purple',
    name: '创意紫',
    primaryColor: Color(0xFF8B5CF6),
    secondaryColor: Color(0xFFA855F7),
    accentColor: Color(0xFF10B981),
    description: '创意 / 年轻',
  ),
  orange(
    id: 'orange',
    name: '活力橙',
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFEA580C),
    accentColor: Color(0xFF0EA5E9),
    description: '活力 / 阳光',
  );

  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.description,
  });

  static ThemePreset fromId(String? id) {
    return ThemePreset.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ThemePreset.pink,
    );
  }
}

/// 主题颜色语义令牌（运行时根据 ThemePreset 计算）
class ThemeColors {
  final ThemePreset preset;

  const ThemeColors(this.preset);

  // 可切换令牌
  Color get primary => preset.primaryColor;
  Color get secondary => preset.secondaryColor;
  Color get accent => preset.accentColor;
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get onSecondary => const Color(0xFFFFFFFF);
  Color get onAccent => const Color(0xFFFFFFFF);

  // primary 的低透明度变体（背景/选中态使用）
  Color get primaryContainer => preset.primaryColor.withValues(alpha: 0.12);
  Color get secondaryContainer => preset.secondaryColor.withValues(alpha: 0.12);
  Color get ring => preset.primaryColor.withValues(alpha: 0.4);

  // 不变令牌（与 DesignTokens 保持一致）
  Color get background => const Color(0xFFF5F5F7);
  Color get surface => const Color(0xFFFFFFFF);
  Color get surfaceVariant => const Color(0xFFFAFAFA);
  Color get onBackground => const Color(0xFF1D1D1F);
  Color get onSurface => const Color(0xFF1D1D1F);
  Color get onSurfaceMuted => const Color(0xFF6E6E73);
  Color get border => const Color(0xFFE5E7EB);
  Color get scrim => const Color(0x80000000);
  Color get destructive => const Color(0xFFDC2626);
  Color get success => const Color(0xFF10B981);
  Color get warning => const Color(0xFFF59E0B);
}
