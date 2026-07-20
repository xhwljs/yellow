import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/api_server_switcher.dart';
import 'package:yellow_depot/core/network/dio_client.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_controller.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';

/// 设置页（列表 + 卷帘菜单版）
///
/// **设计原则**：
/// 与首页"分类目录"卷帘菜单（_showCatalogSheet）保持完全一致的交互模式，
/// 让用户在 app 内任何"选择类"操作都用同一种 bottom sheet 交互。
///
/// - **主列表**：每行 SettingsListTile（icon + 标题 + 当前值 + 右箭头）
///   - 主题色行 → 点击弹出 _showThemeSheet（5 个色块选择）
///   - API 服务器行 → 点击弹出 _showApiServerSheet（镜像列表 + 自定义 URL）
///   - 关于行 → 点击弹出 _showAboutSheet（应用信息详情）
///   - 清除缓存行 → 点击直接执行（不需要选择）
/// - **卷帘菜单**：showModalBottomSheet + drag handle + 标题栏 + 列表
///   风格统一与 home_page._showCatalogSheet 一致
///
/// **保留功能**：
/// - 主题色：5 个预设色块选择 + 当前预设展示
/// - API 服务器：当前 URL + 镜像 chips + 测试连通性 + 自定义 URL + 重置
/// - 关于：应用名/版本/技术栈/设计系统
/// - 清除缓存
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currentBaseUrl;

  @override
  void initState() {
    super.initState();
    _currentBaseUrl = ApiServerSwitcher.current;
  }

  void _refreshBaseUrl() {
    setState(() {
      _currentBaseUrl = ApiServerSwitcher.current;
    });
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
          '设置',
          style: TextStyle(
            color: colors.onBackground,
            fontSize: DesignTokens.textH1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceLg,
          DesignTokens.spaceSm,
          DesignTokens.spaceLg,
          DesignTokens.space2xl,
        ),
        children: [
          // App Hero Header
          _buildAppHero(colors),
          const SizedBox(height: DesignTokens.spaceXl),

          // Group 1: 个性化
          _GroupLabel(text: '个性化', colors: colors),
          const SizedBox(height: DesignTokens.spaceSm),
          _SectionCard(
            colors: colors,
            child: Column(
              children: [
                // 主题色 → 卷帘菜单
                Obx(() {
                  final themeController = Get.find<ThemeController>();
                  final current = themeController.presetRx.value;
                  return _SettingsListTile(
                    icon: PhosphorIconsRegular.palette,
                    iconTone: _IconTone.primary,
                    title: '主题色',
                    subtitle: '${current.name} · ${current.description}',
                    colors: colors,
                    onTap: () => _showThemeSheet(context, colors),
                  );
                }),
                _ListDivider(colors: colors),
                // API 服务器 → 卷帘菜单
                _SettingsListTile(
                  icon: PhosphorIconsRegular.globe,
                  iconTone: _IconTone.primary,
                  title: 'API 服务器',
                  subtitle: _currentBaseUrl,
                  subtitleMaxLines: 1,
                  colors: colors,
                  onTap: () async {
                    await _showApiServerSheet(context, colors);
                    _refreshBaseUrl();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: DesignTokens.spaceXl),

          // Group 2: 关于
          _GroupLabel(text: '关于', colors: colors),
          const SizedBox(height: DesignTokens.spaceSm),
          _SectionCard(
            colors: colors,
            child: Column(
              children: [
                _SettingsListTile(
                  icon: PhosphorIconsRegular.info,
                  iconTone: _IconTone.neutral,
                  title: '应用信息',
                  subtitle: 'v${AppConstants.appVersion}',
                  colors: colors,
                  onTap: () => _showAboutSheet(context, colors),
                ),
                _ListDivider(colors: colors),
                _SettingsListTile(
                  icon: PhosphorIconsRegular.code,
                  iconTone: _IconTone.neutral,
                  title: '技术栈',
                  subtitle: 'Flutter + GetX + Floor',
                  colors: colors,
                  onTap: () => _showAboutSheet(context, colors),
                ),
              ],
            ),
          ),

          const SizedBox(height: DesignTokens.spaceXl),

          // Group 3: 数据
          _GroupLabel(text: '数据', colors: colors),
          const SizedBox(height: DesignTokens.spaceSm),
          _SectionCard(
            colors: colors,
            child: _SettingsListTile(
              icon: PhosphorIconsRegular.trash,
              iconTone: _IconTone.destructive,
              title: '清除缓存',
              subtitle: '清理 Cookie / Session 缓存数据',
              colors: colors,
              showTrailingArrow: false,
              onTap: _clearCache,
            ),
          ),

          const SizedBox(height: DesignTokens.space2xl),
          // 底部版权
          Center(
            child: Text(
              '${AppConstants.appName} · v${AppConstants.appVersion}',
              style: TextStyle(
                fontSize: DesignTokens.textCaption,
                color: colors.onSurfaceMuted.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // App Hero Header — 重新设计（多层渐变 + 沉浸式纹理）
  // ============================================================
  //
  // 设计要点（基于 ui-ux-pro-max 技能建议）：
  // 1. **多层渐变**：LinearGradient (135°) primary → secondary + RadialGradient 光晕
  // 2. **沉浸式纹理**：右上角半透明几何装饰（圆形/方形）增加层次
  // 3. **Logo 卡片**：玻璃拟态效果（BackdropFilter blur）让 logo 浮在主色之上
  // 4. **App 名称**：Poppins Bold，shadow 让白字在彩色背景上更易读
  // 5. **版本徽章**：低透明度白色背景 pill，避免抢戏
  // 6. **副标题**：从主色派生的浅色调，传达"视频聚合"主题
  //
  // 颜色搭配：
  // - 背景：colors.primary → colors.secondary（135° 渐变）
  // - 装饰圆：白色 0.08 / 0.15 透明度，营造层次
  // - 文字：白色（在彩色背景上 WCAG AAA 对比度）
  // - 阴影：colors.primary 30% 透明度，blurRadius 28，模拟 elevation2
  Widget _buildAppHero(ThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceXl,
        DesignTokens.space2xl,
        DesignTokens.spaceXl,
        DesignTokens.spaceXl,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        // 多层渐变：LinearGradient 主渐变 + 通过 Stack 叠加 RadialGradient 光晕
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
          colors: [
            colors.primary,
            colors.secondary,
            colors.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Stack 用于叠加装饰元素
      child: Stack(
        children: [
          // 右上角装饰：半透明圆形 + 方形（几何纹理）
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 18,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -28,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // 主内容
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo 卡片：玻璃拟态效果（半透明白色背景 + blur 模拟）
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.32),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsFill.filmSlate,
                    size: 40,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              // App 名称
              Text(
                AppConstants.appName,
                style: GoogleFonts.poppins(
                  fontSize: DesignTokens.textDisplay,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                  shadows: const [
                    Shadow(
                      color: Color(0x40000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXs),
              // 副标题
              Text(
                '视频聚合 · 随心播放',
                style: GoogleFonts.poppins(
                  fontSize: DesignTokens.textBody,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              // 版本徽章 + 主题色预览圆点
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 版本徽章
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMd,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.32),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.textCaption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  // 主题色名称徽章
                  Obx(() {
                    final themeController = Get.find<ThemeController>();
                    final current = themeController.presetRx.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceMd,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsFill.palette,
                            size: 11,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            current.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: DesignTokens.textCaption,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 卷帘菜单 1: 主题色选择（预设 + 自定义选色盘）
  // ============================================================
  //
  // 风格与 home_page._showCatalogSheet 完全一致：
  // - 圆角顶部 + drag handle
  // - 标题栏：左侧 icon + 标题 + 右侧关闭按钮
  // - 列表项：左侧色块圆点 + 中间 name/description + 右侧 check
  // - 底部增加 HSV 选色盘（CustomColorPicker），用户可拖动选择任意色
  Future<void> _showThemeSheet(BuildContext context, ThemeColors colors) async {
    final themeController = Get.find<ThemeController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                _SheetDragHandle(colors: colors),
                // 标题栏
                _SheetHeader(
                  icon: PhosphorIconsRegular.palette,
                  title: '主题色',
                  colors: colors,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                Divider(height: 1, thickness: 1, color: colors.border),
                // 预设色块列表（可滚动）
                Flexible(
                  child: Obx(() {
                    final current = themeController.presetRx.value;
                    final customColor = themeController.customColorRx.value;
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spaceSm,
                      ),
                      itemCount: ThemePreset.values.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: DesignTokens.spaceLg,
                        endIndent: DesignTokens.spaceLg,
                        color: colors.border.withOpacity(0.5),
                      ),
                      itemBuilder: (_, i) {
                        final preset = ThemePreset.values[i];
                        final selected = preset == current;
                        return _ThemeSheetItem(
                          preset: preset,
                          selected: selected,
                          colors: colors,
                          customColor: preset.isCustom ? customColor : null,
                          onTap: () {
                            themeController.switchPreset(preset);
                            Navigator.of(sheetContext).pop();
                          },
                        );
                      },
                    );
                  }),
                ),
                // 自定义颜色分隔标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spaceLg,
                    DesignTokens.spaceSm,
                    DesignTokens.spaceLg,
                    DesignTokens.spaceXs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.paintBrush,
                        size: 14,
                        color: colors.onSurfaceMuted,
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Text(
                        '自定义颜色',
                        style: TextStyle(
                          fontSize: DesignTokens.textLabel,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // HSV 选色盘 + 预览 + 应用按钮
                _CustomColorSection(
                  colors: colors,
                  onApply: (color) async {
                    await themeController.applyCustomColor(color);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 卷帘菜单 2: API 服务器
  // ============================================================
  Future<void> _showApiServerSheet(
    BuildContext context,
    ThemeColors colors,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return _ApiServerSheet(
          colors: colors,
          currentBaseUrl: _currentBaseUrl,
          onClose: () => Navigator.of(sheetContext).pop(),
          onSwitched: _refreshBaseUrl,
          onCustomUrl: () async {
            Navigator.of(sheetContext).pop();
            await _showCustomUrlDialog();
          },
        );
      },
    );
  }

  // ============================================================
  // 卷帘菜单 3: 关于
  // ============================================================
  Future<void> _showAboutSheet(BuildContext context, ThemeColors colors) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetDragHandle(colors: colors),
              _SheetHeader(
                icon: PhosphorIconsRegular.info,
                title: '关于',
                colors: colors,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              Divider(height: 1, thickness: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceSm,
                ),
                child: Column(
                  children: [
                    _SheetInfoRow(
                      label: '应用名称',
                      value: AppConstants.appName,
                      colors: colors,
                    ),
                    _SheetInfoRow(
                      label: '当前版本',
                      value: 'v${AppConstants.appVersion}',
                      colors: colors,
                    ),
                    _SheetInfoRow(
                      label: '技术栈',
                      value: 'Flutter + GetX + Floor',
                      colors: colors,
                    ),
                    _SheetInfoRow(
                      label: '设计系统',
                      value: 'Yellow Depot MASTER v1.0',
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCustomUrlDialog() async {
    final colors = AppTheme.colorsOf(Get.context!);
    final controller = TextEditingController(text: _currentBaseUrl);
    final result = await Get.dialog<String>(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          '自定义 API URL',
          style: TextStyle(color: colors.onSurface),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'http://example.com',
            hintStyle: TextStyle(color: colors.onSurfaceMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<String>(),
            child: Text(
              '取消',
              style: TextStyle(color: colors.onSurfaceMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Get.back<String>(result: controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && result != _currentBaseUrl) {
      await _switchBaseUrl(result);
    }
  }

  Future<void> _switchBaseUrl(String newUrl) async {
    final colors = AppTheme.colorsOf(Get.context!);
    try {
      await ApiServerSwitcher.switchTo(newUrl);
      _refreshBaseUrl();
      Get.snackbar(
        '已切换',
        '当前 API 服务器：$newUrl',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.surface,
        colorText: colors.onSurface,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '切换失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.destructive,
        colorText: colors.surface,
      );
    }
  }

  Future<void> _clearCache() async {
    final colors = AppTheme.colorsOf(Get.context!);
    try {
      await DioClient.clearCookies();
      Get.snackbar(
        '清除成功',
        '缓存已清理完毕',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.surface,
        colorText: colors.onSurface,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '清除失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.destructive,
        colorText: colors.surface,
        duration: const Duration(seconds: 2),
      );
    }
  }
}

// ============================================================
// Reusable Components
// ============================================================

/// 分组标题
class _GroupLabel extends StatelessWidget {
  final String text;
  final ThemeColors colors;

  const _GroupLabel({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: DesignTokens.spaceXs),
      child: Text(
        text,
        style: TextStyle(
          fontSize: DesignTokens.textLabel,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 通用 Section Card
class _SectionCard extends StatelessWidget {
  final ThemeColors colors;
  final Widget child;

  const _SectionCard({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.elevation1,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// icon 色调（用于区分 destructive 等特殊语义）
enum _IconTone { primary, neutral, destructive }

/// SettingsListTile — 主列表项
///
/// - 左侧 36x36 icon chip（按 tone 着色）
/// - 中间 title + subtitle
/// - 右侧 chevron right（可关闭，用于"清除缓存"等无选择项）
/// - 行内 padding spaceLg × spaceMd，触控目标 ≥56px
class _SettingsListTile extends StatelessWidget {
  final IconData icon;
  final _IconTone iconTone;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final ThemeColors colors;
  final bool showTrailingArrow;
  final VoidCallback onTap;

  const _SettingsListTile({
    required this.icon,
    required this.iconTone,
    required this.title,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.showTrailingArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconFg) = switch (iconTone) {
      _IconTone.primary =>
        (colors.primary.withOpacity(0.12), colors.primary),
      _IconTone.neutral =>
        (colors.onSurfaceMuted.withOpacity(0.12), colors.onSurfaceMuted),
      _IconTone.destructive =>
        (colors.destructive.withOpacity(0.12), colors.destructive),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLg,
            vertical: DesignTokens.spaceMd,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconFg,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: DesignTokens.textBody,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: DesignTokens.textCaption,
                          color: colors.onSurfaceMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTrailingArrow) ...[
                const SizedBox(width: DesignTokens.spaceSm),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: colors.onSurfaceMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 行内分割线（带 indent）
class _ListDivider extends StatelessWidget {
  final ThemeColors colors;
  const _ListDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: DesignTokens.spaceLg + 36 + DesignTokens.spaceMd,
      endIndent: DesignTokens.spaceLg,
      color: colors.border.withOpacity(0.6),
    );
  }
}

// ============================================================
// Bottom Sheet 共用组件
// ============================================================

/// 卷帘菜单 drag handle
class _SheetDragHandle extends StatelessWidget {
  final ThemeColors colors;
  const _SheetDragHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: DesignTokens.spaceSm),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// 卷帘菜单标题栏
class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeColors colors;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceLg,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceSm,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Text(
            title,
            style: TextStyle(
              fontSize: DesignTokens.textH2,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSm,
                vertical: DesignTokens.spaceXs,
              ),
              child: Icon(
                PhosphorIconsRegular.x,
                size: 20,
                color: colors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卷帘菜单信息行（label : value）
class _SheetInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeColors colors;

  const _SheetInfoRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLg,
        vertical: DesignTokens.spaceMd,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textBody,
              color: colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: DesignTokens.textBody,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题色卷帘菜单项
class _ThemeSheetItem extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  /// 自定义模式下的实际颜色（仅 preset == ThemePreset.custom 时使用）
  ///
  /// 由调用方传入 ThemeController.customColor，用于色块圆点显示真实颜色，
  /// 而非枚举的占位色。
  final Color? customColor;

  const _ThemeSheetItem({
    required this.preset,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    // 实际显示颜色：custom 预设用 customColor，其他用 preset.primaryColor
    final displayColor = preset.isCustom
        ? (customColor ?? ThemePreset.pink.primaryColor)
        : preset.primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLg,
            vertical: DesignTokens.spaceMd,
          ),
          child: Row(
            children: [
              // 色块圆点（custom 预设显示用户保存的实际颜色）
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: displayColor,
                  shape: BoxShape.circle,
                  boxShadow: DesignTokens.elevation1,
                ),
                child: selected
                    ? Center(
                        child: Icon(
                          PhosphorIconsFill.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              // name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: DesignTokens.textBody,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.description,
                      style: TextStyle(
                        fontSize: DesignTokens.textCaption,
                        color: colors.onSurfaceMuted,
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
}

// ============================================================
// API 服务器卷帘菜单
// ============================================================

/// API 服务器卷帘菜单
///
/// 与首页 catalog sheet 同款风格：
/// - drag handle + 标题栏
/// - 当前 URL + 状态徽章
/// - 镜像列表（chip 风格，复用 _MirrorChip）
/// - 自定义 URL / 测试连通性 / 重置按钮
class _ApiServerSheet extends StatefulWidget {
  final ThemeColors colors;
  final String currentBaseUrl;
  final VoidCallback onClose;
  final VoidCallback onSwitched;
  final Future<void> Function() onCustomUrl;

  const _ApiServerSheet({
    required this.colors,
    required this.currentBaseUrl,
    required this.onClose,
    required this.onSwitched,
    required this.onCustomUrl,
  });

  @override
  State<_ApiServerSheet> createState() => _ApiServerSheetState();
}

class _ApiServerSheetState extends State<_ApiServerSheet> {
  late String _currentBaseUrl;
  bool _testingUrl = false;
  String? _testResult;
  bool _hasTested = false;

  @override
  void initState() {
    super.initState();
    _currentBaseUrl = widget.currentBaseUrl;
  }

  ThemeColors get colors => widget.colors;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetDragHandle(colors: colors),
            _SheetHeader(
              icon: PhosphorIconsRegular.globe,
              title: 'API 服务器',
              colors: colors,
              onClose: widget.onClose,
            ),
            Divider(height: 1, thickness: 1, color: colors.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(DesignTokens.spaceLg),
                children: [
                  // 当前 URL + 状态徽章
                  _buildCurrentRow(),
                  if (_testResult != null) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      '连接失败：$_testResult',
                      style: TextStyle(
                        fontSize: DesignTokens.textCaption,
                        color: colors.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: DesignTokens.spaceLg),

                  // 镜像列表
                  _buildSubLabel('镜像列表'),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Wrap(
                    spacing: DesignTokens.spaceSm,
                    runSpacing: DesignTokens.spaceSm,
                    children: ApiServerSwitcher.presetMirrors.map((url) {
                      final selected = url == _currentBaseUrl;
                      return _MirrorChip(
                        url: url,
                        selected: selected,
                        colors: colors,
                        onTap: () => _switchBaseUrl(url),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: DesignTokens.spaceLg),

                  // 操作按钮 — 按重要性分层
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _testingUrl ? null : _testConnectivity,
                      icon: const Icon(PhosphorIconsRegular.plugsConnected),
                      label: const Text('测试连通性'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceLg,
                          vertical: DesignTokens.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        widget.onClose();
                        await widget.onCustomUrl();
                      },
                      icon: const Icon(PhosphorIconsRegular.pencilSimpleLine),
                      label: const Text('自定义 URL'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.border),
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceLg,
                          vertical: DesignTokens.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _switchBaseUrl(AppConstants.defaultBaseUrl),
                      icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise),
                      label: const Text('重置为默认'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceMuted,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentRow() {
    return Row(
      children: [
        Icon(
          PhosphorIconsRegular.link,
          size: 14,
          color: colors.onSurfaceMuted,
        ),
        const SizedBox(width: DesignTokens.spaceXs),
        Expanded(
          child: Text(
            _currentBaseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_testingUrl)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_testResult != null)
          _StatusBadge(
            text: '失败',
            icon: PhosphorIconsFill.warningCircle,
            tone: _StatusTone.destructive,
            colors: colors,
            compact: true,
          )
        else if (_hasTested)
          _StatusBadge(
            text: '已连通',
            icon: PhosphorIconsFill.checkCircle,
            tone: _StatusTone.success,
            colors: colors,
            compact: true,
          ),
      ],
    );
  }

  Widget _buildSubLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: DesignTokens.textLabel,
        fontWeight: FontWeight.w600,
        color: colors.onSurfaceMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Future<void> _switchBaseUrl(String newUrl) async {
    try {
      await ApiServerSwitcher.switchTo(newUrl);
      setState(() {
        _currentBaseUrl = newUrl;
        _testResult = null;
        _hasTested = false;
      });
      widget.onSwitched();
      Get.snackbar(
        '已切换',
        '当前 API 服务器：$newUrl',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.surface,
        colorText: colors.onSurface,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '切换失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: colors.destructive,
        colorText: colors.surface,
      );
    }
  }

  Future<void> _testConnectivity() async {
    setState(() {
      _testingUrl = true;
      _testResult = null;
    });
    final result = await ApiServerSwitcher.testConnectivity(_currentBaseUrl);
    if (!mounted) return;
    setState(() {
      _testingUrl = false;
      _testResult = result;
      _hasTested = true;
    });
  }
}

// ============================================================
// 共用小组件
// ============================================================

/// 状态徽章色调
enum _StatusTone { success, destructive, neutral }

/// 状态徽章
class _StatusBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final _StatusTone tone;
  final ThemeColors colors;
  final bool compact;

  const _StatusBadge({
    required this.text,
    required this.icon,
    required this.tone,
    required this.colors,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      _StatusTone.success => (colors.success, colors.success.withOpacity(0.12)),
      _StatusTone.destructive =>
        (colors.destructive, colors.destructive.withOpacity(0.12)),
      _StatusTone.neutral => (colors.onSurfaceMuted, colors.surfaceVariant),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DesignTokens.spaceSm : DesignTokens.spaceMd,
        vertical: compact ? 2 : DesignTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact
                    ? DesignTokens.textLabel
                    : DesignTokens.textCaption,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 镜像 URL chip
class _MirrorChip extends StatelessWidget {
  final String url;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _MirrorChip({
    required this.url,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.primary.withOpacity(0.1) : colors.surfaceVariant,
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 12,
                  color: colors.primary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                url,
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colors.primary : colors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 自定义颜色选择器（HSV 选色盘 + 色相滑块 + 预览 + 应用按钮）
// ============================================================

/// 自定义颜色选择区域
///
/// 包含：
/// - **HSV 色盘**：饱和度 × 明度（SV）方形面板，可拖动选择
/// - **色相滑块**：横向彩虹条，可拖动选择色相（H）
/// - **预览圆点**：显示当前选中的颜色 + Hex 值
/// - **应用按钮**：点击后将颜色应用到主题
///
/// 设计：
/// - SV 面板用 CustomPaint 绘制（水平饱和度 0→1，垂直明度 1→0）
/// - 色相滑块用 7 段彩虹渐变 LinearGradient（red→yellow→green→cyan→blue→magenta→red）
/// - 拖动通过 GestureDetector 监听 onPanUpdate
/// - 触摸目标 ≥44pt（满足 a11y 要求）
class _CustomColorSection extends StatefulWidget {
  final ThemeColors colors;
  final Future<void> Function(Color color) onApply;

  const _CustomColorSection({
    required this.colors,
    required this.onApply,
  });

  @override
  State<_CustomColorSection> createState() => _CustomColorSectionState();
}

class _CustomColorSectionState extends State<_CustomColorSection> {
  /// 当前选中的 HSV 颜色（默认初始为当前主题色对应的 HSV）
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    // 初始 HSV 用当前主题色（让用户从当前色开始调整，更自然）
    _hsv = HSVColor.fromColor(widget.colors.primary);
  }

  /// 当前 HSV 对应的 RGB Color
  Color get _currentColor => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final currentColor = _currentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceLg,
        DesignTokens.spaceXs,
        DesignTokens.spaceLg,
        DesignTokens.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SV 选色盘（饱和度 × 明度）
          _buildSvPanel(colors, currentColor),
          const SizedBox(height: DesignTokens.spaceSm),
          // 色相滑块
          _buildHueSlider(colors),
          const SizedBox(height: DesignTokens.spaceMd),
          // 预览 + Hex 值 + 应用按钮
          _buildPreviewAndApply(colors, currentColor),
        ],
      ),
    );
  }

  /// SV 色盘：水平方向 = 饱和度，垂直方向 = 明度（上=1, 下=0）
  ///
  /// 背景：左侧白 → 右侧当前色相（饱和度渐变）
  ///      叠加：上透明 → 下黑（明度渐变）
  /// 用两层 Stack 实现（Flutter 不能直接画 HSV gradient）
  Widget _buildSvPanel(ThemeColors colors, Color currentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 固定高度 180，宽度填满
        const height = 180.0;
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (details) =>
              _updateFromSv(details.localPosition, width, height),
          onPanUpdate: (details) =>
              _updateFromSv(details.localPosition, width, height),
          child: Container(
            width: double.infinity,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Stack(
              children: [
                // 底层：水平白色 → 当前色相饱和色
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          _hsv.withSaturation(1).withValue(1).toColor(),
                        ],
                      ),
                    ),
                  ),
                ),
                // 上层：垂直透明 → 黑色（明度渐变）
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
                // 当前位置指示器（圆环）
                Positioned(
                  left: (_hsv.saturation * width).clamp(0.0, width - 24) - 12,
                  top: ((1 - _hsv.value) * height).clamp(0.0, height - 24) - 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 色相滑块：横向 7 段彩虹渐变
  Widget _buildHueSlider(ThemeColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 28.0;
        return GestureDetector(
          onPanDown: (details) =>
              _updateFromHue(details.localPosition.dx, width),
          onPanUpdate: (details) =>
              _updateFromHue(details.localPosition.dx, width),
          child: Container(
            width: double.infinity,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Stack(
              children: [
                // 彩虹渐变
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFFFF0000), // red 0°
                          const Color(0xFFFFFF00), // yellow 60°
                          const Color(0xFF00FF00), // green 120°
                          const Color(0xFF00FFFF), // cyan 180°
                          const Color(0xFF0000FF), // blue 240°
                          const Color(0xFFFF00FF), // magenta 300°
                          const Color(0xFFFF0000), // red 360°
                        ],
                      ),
                    ),
                  ),
                ),
                // 当前色相指示器（白色圆环）
                Positioned(
                  left: (_hsv.hue / 360 * width).clamp(0.0, width - 20) - 10,
                  top: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hsv.withSaturation(1).withValue(1).toColor(),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 预览 + Hex 值 + 应用按钮
  Widget _buildPreviewAndApply(ThemeColors colors, Color currentColor) {
    final hex = _colorToHex(currentColor);
    return Row(
      children: [
        // 预览圆点
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border, width: 1.5),
            boxShadow: DesignTokens.elevation1,
          ),
        ),
        const SizedBox(width: DesignTokens.spaceMd),
        // Hex 值
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '当前选择',
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  color: colors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hex,
                style: TextStyle(
                  fontSize: DesignTokens.textBody,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // 应用按钮
        FilledButton.icon(
          onPressed: () => widget.onApply(currentColor),
          icon: const Icon(PhosphorIconsFill.check, size: 16),
          label: const Text('应用'),
          style: FilledButton.styleFrom(
            backgroundColor: currentColor,
            foregroundColor: _isLight(currentColor) ? Colors.black : Colors.white,
            minimumSize: const Size(56, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            ),
          ),
        ),
      ],
    );
  }

  /// 根据触摸位置更新 SV
  void _updateFromSv(Offset localPosition, double width, double height) {
    setState(() {
      final s = (localPosition.dx / width).clamp(0.0, 1.0);
      final v = (1 - localPosition.dy / height).clamp(0.0, 1.0);
      _hsv = _hsv.withSaturation(s).withValue(v);
    });
  }

  /// 根据触摸位置更新色相
  void _updateFromHue(double dx, double width) {
    setState(() {
      final h = (dx / width).clamp(0.0, 1.0) * 360;
      _hsv = _hsv.withHue(h);
    });
  }

  /// Color 转 #RRGGBB 字符串
  static String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  /// 判断颜色是否为浅色（用于决定按钮文字颜色）
  static bool _isLight(Color color) {
    // 标准亮度公式：0.299R + 0.587G + 0.114B
    final luminance =
        0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    return luminance > 0.6;
  }
}
