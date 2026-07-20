import 'package:flutter/material.dart';

/// 主题预设 — 5 套预设主题色 + 1 套自定义色
///
/// 严格遵循 design-system/videohub/MASTER.md §3.2
/// 所有主题使用同一浅色背景（#F5F5F7），仅切换 primary/secondary/accent 三个语义令牌。
///
/// [custom] 预设允许用户从 HSV 选色盘选择任意 primary 色，
/// secondary 由 primary 自动派生（HSV 降低 V 8%），accent 固定为蓝。
/// 自定义色的具体值由 [ThemeController.customColor] 持久化保存，
/// 不在枚举里硬编码（枚举只是占位符，运行时由控制器注入实际颜色）。
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
  ),
  /// 自定义色 — 由用户从 HSV 选色盘选择
  ///
  /// primaryColor 是占位符（启动时由 ThemeController 覆盖为用户保存的颜色）。
  /// 枚举值存在的目的：让 [AppTheme._presetOf] 能识别"当前是 custom 模式"，
  /// 从而走 [ThemeController.customPrimaryColor] 而非枚举的 primaryColor。
  custom(
    id: 'custom',
    name: '自定义',
    primaryColor: Color(0xFFEC4899), // 占位，实际由 ThemeController 覆盖
    secondaryColor: Color(0xFFDB2777),
    accentColor: Color(0xFF2563EB),
    description: '从选色盘自定义',
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

  /// 是否为自定义色预设
  bool get isCustom => this == ThemePreset.custom;
}

/// 主题颜色语义令牌（运行时根据 ThemePreset 计算）
class ThemeColors {
  final ThemePreset preset;

  /// 自定义 primary 色（仅 preset == ThemePreset.custom 时生效）
  ///
  /// 由 [ThemeController] 在构造时传入用户持久化的颜色。
  /// 预设模式下此字段被忽略。
  final Color? customPrimary;

  const ThemeColors(this.preset, {this.customPrimary});

  /// 实际生效的 primary 色
  ///
  /// - 预设模式：返回 preset.primaryColor
  /// - 自定义模式：返回 customPrimary（如未设置则回退到 pink）
  Color get primary {
    if (preset.isCustom) {
      return customPrimary ?? ThemePreset.pink.primaryColor;
    }
    return preset.primaryColor;
  }

  /// secondary — 自定义模式下由 primary HSV 派生（V 降低 8%）
  Color get secondary {
    if (preset.isCustom) {
      return _darken(primary, 0.08);
    }
    return preset.secondaryColor;
  }

  Color get accent => preset.accentColor;
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get onSecondary => const Color(0xFFFFFFFF);
  Color get onAccent => const Color(0xFFFFFFFF);

  // primary 的低透明度变体（背景/选中态使用）
  Color get primaryContainer => primary.withOpacity(0.12);
  Color get secondaryContainer => secondary.withOpacity(0.12);
  Color get ring => primary.withOpacity(0.4);

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

  /// 把颜色按 HSV 的 V 通道降低 [amount]（0-1）
  ///
  /// 用于自定义模式从 primary 派生 secondary 色。
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
