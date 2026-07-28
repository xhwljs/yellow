import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）— 单一真理源
///
/// 严格遵循 design-system/videohub/MASTER.md §2 定义。
/// 任何页面、组件不得硬编码 hex 值或像素值。
class DesignTokens {
  DesignTokens._();

  // ===== Spacing (8dp rhythm) =====
  static const double space3xs = 2; // badge / 紧凑内边距
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

  // ===== Icon Size (语义令牌) =====
  // 用于 UI 中所有 Icon / phosphor 图标的尺寸，避免散落硬编码。
  static const double iconSize2xs = 11;
  static const double iconSizeXs = 12;
  static const double iconSizeSm = 14;
  static const double iconSizeMd = 16;
  static const double iconSizeLg = 18;
  static const double iconSizeXl = 24;
  static const double iconSize2xl = 32;
  static const double iconSize3xl = 40;
  static const double iconSize4xl = 48;
  static const double iconSize5xl = 64;
  static const double iconSizeAction = 20; // header / 搜索 / 卷帘菜单标题图标

  // ===== Media Size (语义令牌) =====
  // 用于封面 / 头像 / Logo / 按钮 等具名尺寸。
  static const double mediaLogoSize = 96;
  static const double mediaAvatarSize = 48;
  static const double mediaInlineHeight = 200;
  static const double mediaCardWidth = 160;
  static const double mediaPlayButtonSize = 72;
  static const double appBarExpandedHeight = 220;
  static const double bottomNavHeight = 80;
  static const double bottomSheetHandleWidth = 36;
  static const double bottomSheetHandleHeight = 4;

  // ===== Component Size (语义令牌) =====
  // 用于具体组件的具名尺寸，避免散落硬编码。
  static const double progressBarHeight = 3; // LinearProgressIndicator minHeight
  static const double skeletonBarHeight = 12; // 骨架屏文本条高度
  static const double skeletonBarShortWidth = 100; // 骨架屏短文本条宽度
  static const double dividerThickness = 1; // 发丝分割线
  static const double iconChipSize = 36; // 设置项 icon chip
  static const double colorSwatchSize = 32; // 主题色块圆点
  static const double toastRingSize = 28; // 退出提示倒计时环
  static const double overlayLoadingSize = 44; // 视频封面 loading 圈
  static const double chipProgressSize = 10; // 镜像 chip 测试中 loading 圈
  static const double tabBarHeight = 40; // 分类 Tab 栏高度

  // ===== Border Width (语义令牌) =====
  static const double borderWidthThin = 0.5; // 超细边框
  static const double borderWidthHairline = 1; // 发丝边框
  static const double borderWidthMedium = 1.5; // 选中态边框
  static const double borderWidthThick = 2; // 聚焦 / 强调边框
  static const double borderWidthIndicator = 3; // 选色盘指示器圆环

  // ===== Progress Stroke Width (语义令牌) =====
  static const double progressStrokeThin = 1.5;
  static const double progressStrokeMedium = 2;
  static const double progressStrokeThick = 2.5;
  static const double progressStrokeXl = 3;

  // ===== Color Picker (语义令牌) =====
  static const double colorPickerSvHeight = 180; // SV 色盘高度
  static const double colorPickerSliderHeight = 28; // 色相滑块高度
  static const double colorPickerIndicatorLg = 24; // SV 位置指示器
  static const double colorPickerIndicatorSm = 20; // 色相位置指示器
  static const List<BoxShadow> colorPickerIndicatorShadow = const [
    BoxShadow(
      color: Color(0x4D000000), // rgba(0,0,0,0.3)
      blurRadius: 4,
      offset: elevationOffsetSm,
    ),
  ];

  // ===== Elevation Offset (语义令牌) =====
  // 用于 BoxShadow offset，与 elevation1/2/3 配套使用。
  static const Offset elevationOffsetSm = Offset(0, 1);
  static const Offset elevationOffsetMd = Offset(0, 4);
  static const Offset elevationOffsetLg = Offset(0, 8);
  static const Offset elevationOffsetXl = Offset(0, 12);

  // ===== Elevation Blur Radius (语义令牌) =====
  // 与 elevation1/2/3 配套使用，自定义阴影也可复用。
  static const double elevation1BlurRadius = 2;
  static const double elevation2BlurRadius = 12;
  static const double elevation3BlurRadius = 24;

  // ===== Elevation (Shadows) =====
  static const List<BoxShadow> elevation0 = const [];

  static const List<BoxShadow> elevation1 = const [
    BoxShadow(
      color: Color(0x0A000000), // rgba(0,0,0,0.04)
      blurRadius: elevation1BlurRadius,
      offset: elevationOffsetSm,
    ),
  ];

  static const List<BoxShadow> elevation2 = const [
    BoxShadow(
      color: Color(0x14000000), // rgba(0,0,0,0.08)
      blurRadius: elevation2BlurRadius,
      offset: elevationOffsetMd,
    ),
  ];

  static const List<BoxShadow> elevation3 = const [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0,0,0,0.12)
      blurRadius: elevation3BlurRadius,
      offset: elevationOffsetLg,
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
  static const double videoGridChildAspectRatio = 0.88;
}
