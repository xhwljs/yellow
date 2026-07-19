import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_presets.dart';

/// AppTheme — 基于 ThemePreset 生成 ThemeData
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 仅浅色模式（brightness: Brightness.light）
/// - 不生成 darkTheme
/// - 字体：Righteous (display) + Poppins (body) + JetBrains Mono (mono)
class AppTheme {
  AppTheme._();

  static ThemeData fromPreset(ThemePreset preset) {
    final colors = ThemeColors(preset);
    final scheme = ColorScheme.light(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      tertiary: colors.accent,
      onTertiary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.onSurface,
      background: colors.background,
      onBackground: colors.onBackground,
      error: colors.destructive,
      onError: const Color(0xFFFFFFFF),
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: const Color(0xFF000000),
      scrim: colors.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.surface,
      dividerColor: colors.border,
      dialogBackgroundColor: colors.surface,
      // 字体
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _buildTextTheme(colors),
      primaryTextTheme: _buildTextTheme(colors),
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.textH1,
          fontWeight: FontWeight.w700,
          color: colors.onBackground,
        ),
      ),
      // Card
      cardTheme: CardTheme(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
      ),
      // 按钮
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceXl,
            vertical: DesignTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: DesignTokens.textBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      // IconButton
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        selectedColor: colors.primaryContainer,
        labelStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.textCaption,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
        side: BorderSide(color: colors.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceXs,
        ),
      ),
      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceLg,
          vertical: DesignTokens.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(color: colors.destructive, width: 1),
        ),
        labelStyle: GoogleFonts.poppins(
          color: colors.onSurfaceMuted,
          fontSize: DesignTokens.textBody,
        ),
        hintStyle: GoogleFonts.poppins(
          color: colors.onSurfaceMuted,
          fontSize: DesignTokens.textBody,
        ),
      ),
      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.textLabel,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.textLabel,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      // Progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.border,
        circularTrackColor: colors.border,
      ),
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onBackground,
        contentTextStyle: GoogleFonts.poppins(
          color: colors.surface,
          fontSize: DesignTokens.textBody,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
      ),
      // 页面过渡（GetX 会接管，这里设默认）
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 选中态颜色
      listTileTheme: ListTileThemeData(
        selectedColor: colors.primary,
        iconColor: colors.onSurfaceMuted,
      ),
      // 涟漪效果颜色
      splashColor: colors.primary.withValues(alpha: 0.08),
      highlightColor: colors.primary.withValues(alpha: 0.04),
    );
  }

  static TextTheme _buildTextTheme(ThemeColors colors) {
    final poppins = GoogleFonts.poppins;
    final righteous = GoogleFonts.righteous;
    final mono = GoogleFonts.jetBrainsMono;

    return TextTheme(
      displayLarge: righteous(
        fontSize: DesignTokens.textDisplay,
        fontWeight: FontWeight.w400,
        color: colors.onBackground,
      ),
      displayMedium: righteous(
        fontSize: DesignTokens.textH1,
        fontWeight: FontWeight.w400,
        color: colors.onBackground,
      ),
      headlineMedium: poppins(
        fontSize: DesignTokens.textH1,
        fontWeight: FontWeight.w700,
        color: colors.onBackground,
      ),
      titleLarge: poppins(
        fontSize: DesignTokens.textH2,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleMedium: poppins(
        fontSize: DesignTokens.textBody,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      bodyLarge: poppins(
        fontSize: DesignTokens.textBody,
        fontWeight: FontWeight.w400,
        color: colors.onSurface,
      ),
      bodyMedium: poppins(
        fontSize: DesignTokens.textCaption,
        fontWeight: FontWeight.w400,
        color: colors.onSurfaceMuted,
      ),
      labelLarge: poppins(
        fontSize: DesignTokens.textLabel,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      labelSmall: poppins(
        fontSize: DesignTokens.textLabel,
        fontWeight: FontWeight.w500,
        color: colors.onSurfaceMuted,
      ),
    ).apply(
      bodyColor: colors.onBackground,
      displayColor: colors.onBackground,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );
  }

  /// 获取当前 ThemeColors（用于自定义 widget 读取语义令牌）
  static ThemeColors colorsOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    assert(brightness == Brightness.light, 'VideoHub 仅支持浅色模式');
    return ThemeColors(_presetOf(context));
  }

  static ThemePreset _presetOf(BuildContext context) {
    // 通过 InheritedWidget 或 GetX tag 注入
    // 这里直接读 Theme primary 推断 preset（兜底）
    final primary = Theme.of(context).colorScheme.primary;
    for (final preset in ThemePreset.values) {
      if (preset.primaryColor.value == primary.value) {
        return preset;
      }
    }
    return ThemePreset.pink;
  }
}
