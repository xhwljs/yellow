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
  // App Hero Header
  // ============================================================
  Widget _buildAppHero(ThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.spaceXl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: DesignTokens.elevation2,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsFill.filmSlate,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            AppConstants.appName,
            style: GoogleFonts.poppins(
              fontSize: DesignTokens.textDisplay,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
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
        ],
      ),
    );
  }

  // ============================================================
  // 卷帘菜单 1: 主题色选择
  // ============================================================
  //
  // 风格与 home_page._showCatalogSheet 完全一致：
  // - 圆角顶部 + drag handle
  // - 标题栏：左侧 icon + 标题 + 右侧关闭按钮
  // - 列表项：左侧色块圆点 + 中间 name/description + 右侧 check
  Future<void> _showThemeSheet(BuildContext context, ThemeColors colors) async {
    final themeController = Get.find<ThemeController>();
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
              // 色块列表
              Flexible(
                child: Obx(() {
                  final current = themeController.presetRx.value;
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
                        onTap: () {
                          themeController.switchPreset(preset);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
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

  const _ThemeSheetItem({
    required this.preset,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              // 色块圆点
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: preset.primaryColor,
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
