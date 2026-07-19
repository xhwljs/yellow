import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）— 单一真理源
///
/// 严格遵循 design-system/videohub/MASTER.md §2 定义。
/// 任何页面、组件不得硬编码 hex 值或像素值。
class DesignTokens {
  DesignTokens._();

  // ===== Spacing (8dp rhythm) =====
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;

  // ===== Radius =====
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 999;
  static const double radiusFull = 999;

  // ===== Typography Scale =====
  static const double textDisplay = 28;
  static const double textH1 = 22;
  static const double textH2 = 18;
  static const double textBody = 14;
  static const double textCaption = 12;
  static const double textLabel = 11;

  // ===== Motion Duration (ms) =====
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 400);
  static const Duration motionSlower = Duration(milliseconds: 600);

  // ===== Elevation (Shadows) =====
  static List<BoxShadow> elevation1 = const [
    BoxShadow(
      color: Color(0x0A000000), // rgba(0,0,0,0.04)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> elevation2 = const [
    BoxShadow(
      color: Color(0x14000000), // rgba(0,0,0,0.08)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevation3 = const [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0,0,0,0.12)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // ===== 不变颜色（所有主题共享） =====
  // 严格遵循 MASTER.md §3.1
  static const Color colorBackground = Color(0xFFF5F5F7); // Off-white
  static const Color colorSurface = Color(0xFFFFFFFF); // Pure white
  static const Color colorSurfaceVariant = Color(0xFFFAFAFA);
  static const Color colorOnBackground = Color(0xFF1D1D1F);
  static const Color colorOnSurface = Color(0xFF1D1D1F);
  static const Color colorOnSurfaceMuted = Color(0xFF6E6E73);
  static const Color colorBorder = Color(0xFFE5E7EB);
  static const Color colorScrim = Color(0x80000000); // rgba(0,0,0,0.5)
  static const Color colorDestructive = Color(0xFFDC2626);
  static const Color colorSuccess = Color(0xFF10B981);
  static const Color colorWarning = Color(0xFFF59E0B);
  static const Color colorSkeleton = Color(0xFFE5E7EB);
  static const Color colorVideoOverlay = Color(0x66000000); // rgba(0,0,0,0.4)

  // ===== 视频卡片尺寸 =====
  static const double videoCardAspectRatio = 16 / 9; // 列表卡片
  static const double videoCardHeroAspectRatio = 9 / 16; // Hero 卡片
  static const int videoGridCrossAxisCount = 2;
  static const double videoGridSpacing = 12;
  static const double videoGridMainAxisSpacing = 12;
}
