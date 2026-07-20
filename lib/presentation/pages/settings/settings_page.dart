import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
          // App Header（扁平卡片风格，与其它页一致）
          _buildAppHeader(colors),
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
  // App Header — 扁平卡片风格（与其它页 _SectionCard 一致）
  // ============================================================
  //
  // 设计原则：与 home_page / favorites_page / history_page 风格统一。
  // 这些页面均为 MD3 扁平卡片（surface + radiusLg + elevation1），
  // 不使用渐变、几何装饰、玻璃拟态、GoogleFonts.poppins。
  //
  // 本 Header 与 _SettingsListTile 共享视觉语言：
  // - 左侧 48x48 icon chip（primary 浅色背景 + primary 前景）
  // - 中间 title（textH2 + w700 + onBackground）+ subtitle（textCaption + onSurfaceMuted）
  // - 右侧 trailing：主题色圆点 + 主题名 caption（点击可切换主题）
  // - 整行 InkWell，点击进入主题色卷帘菜单
  Widget _buildAppHeader(ThemeColors colors) {
    return _SectionCard(
      colors: colors,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showThemeSheet(context, colors),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLg,
              vertical: DesignTokens.spaceLg,
            ),
            child: Row(
              children: [
                // 左侧 icon chip
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIconsFill.filmSlate,
                      size: 24,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                // 中间：App 名称 + 副标题 + 版本号
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: DesignTokens.textH2,
                          fontWeight: FontWeight.w700,
                          color: colors.onBackground,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '视频聚合 · 随心播放',
                        style: TextStyle(
                          fontSize: DesignTokens.textCaption,
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${AppConstants.appVersion}',
                        style: TextStyle(
                          fontSize: DesignTokens.textCaption,
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧：主题色圆点 + 主题名
                Obx(() {
                  final themeController = Get.find<ThemeController>();
                  final current = themeController.presetRx.value;
                  final dotColor = current.isCustom
                      ? themeController.customColorRx.value
                      : current.primaryColor;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: DesignTokens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXs),
                        Text(
                          current.name,
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXs),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 14,
                          color: colors.onSurfaceMuted,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 卷帘菜单 1: 主题色选择（仅预设列表 + 自定义入口项）
  // ============================================================
  //
  // 交互设计：
  // - 主菜单显示 5 个预设色块 + 1 个「自定义」入口项（与其它项同款 _ThemeSheetItem）
  // - 点击预设项：直接应用并关闭菜单
  // - 点击「自定义」项：先关闭主菜单，再弹出 _showCustomColorSheet 二级菜单显示 HSV 选色盘
  //
  // 这样默认卷帘菜单保持简洁（与其他卷帘菜单 _showApiServerSheet / _showAboutSheet 视觉一致），
  // 仅当用户主动选择"自定义"时才进入选色盘交互。
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
              // 预设色块列表（5 个预设 + 1 个自定义入口，共 6 项）
              Obx(() {
                final current = themeController.presetRx.value;
                final customColor = themeController.customColorRx.value;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                      onTap: () async {
                        if (preset.isCustom) {
                          // 自定义入口：关闭主菜单后弹出选色盘二级菜单
                          Navigator.of(sheetContext).pop();
                          await _showCustomColorSheet(context, colors);
                        } else {
                          // 普通预设：直接应用并关闭
                          await themeController.switchPreset(preset);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }
                      },
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 卷帘菜单 1b: 自定义颜色选色盘（点「自定义」入口后才弹出）
  // ============================================================
  //
  // 二级卷帘菜单，仅当用户在主题色主菜单点「自定义」时调用。
  // 风格与 _showThemeSheet / _showApiServerSheet 完全一致：
  // drag handle + 标题栏（"自定义颜色" + 关闭按钮）+ HSV 选色盘 + 应用按钮。
  //
  // 选色盘初始 HSV 从当前 ThemeController.colors.primary 派生：
  // - 如果之前选过自定义色 → 从该色开始调整
  // - 如果是从其它预设过来 → 从该预设的 primary 开始调整
  Future<void> _showCustomColorSheet(
    BuildContext context,
    ThemeColors colors,
  ) async {
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
                _SheetDragHandle(colors: colors),
                _SheetHeader(
                  icon: PhosphorIconsRegular.paintBrush,
                  title: '自定义颜色',
                  colors: colors,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                Divider(height: 1, thickness: 1, color: colors.border),
                // HSV 选色盘（_CustomColorSection 从当前 colors.primary 初始化）
                Flexible(
                  child: SingleChildScrollView(
                    child: _CustomColorSection(
                      colors: colors,
                      onApply: (color) async {
                        await themeController.applyCustomColor(color);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
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
        // 自定义 URL 输入框已内部化到 _ApiServerSheet，
        // 避免之前 sheet pop + Get.dialog push 之间的 race condition 闪退
        return _ApiServerSheet(
          colors: colors,
          currentBaseUrl: _currentBaseUrl,
          onClose: () => Navigator.of(sheetContext).pop(),
          onSwitched: _refreshBaseUrl,
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

  const _ApiServerSheet({
    required this.colors,
    required this.currentBaseUrl,
    required this.onClose,
    required this.onSwitched,
  });

  @override
  State<_ApiServerSheet> createState() => _ApiServerSheetState();
}

class _ApiServerSheetState extends State<_ApiServerSheet> {
  late String _currentBaseUrl;

  /// 测试开始时的 baseUrl，用于测试完成后判断是否发生自动迁移
  String? _originalBaseUrlBeforeTest;

  /// "测试连通性"按钮状态
  bool _testingUrl = false;
  String? _testResult;
  bool _hasTested = false;

  /// 镜像列表自动测试状态（打开 sheet 时异步触发）
  ///
  /// - true：正在批量测试镜像列表
  /// - false：测试完成（无论成功失败）
  bool _autoTestingMirrors = false;

  /// 每个镜像的测试状态（autoTestMirrors 完成后填充）
  ///
  /// - true：通过（真实源站 / 已迁移到最新）
  /// - false：失败（不可访问 / 跳转壳无法迁移）
  /// - null：未测试
  final Map<String, bool?> _mirrorStatus = {};

  @override
  void initState() {
    super.initState();
    _currentBaseUrl = widget.currentBaseUrl;
    // 打开 sheet 时自动测试镜像列表（异步触发，不阻塞 UI 渲染）
    _autoTestMirrors();
  }

  ThemeColors get colors => widget.colors;

  /// 批量测试镜像列表中的所有 URL，发现跳转壳则自动迁移到最新地址
  ///
  /// 调用 [ApiServerSwitcher.autoTestMirrors]，完成后更新 UI：
  /// - 标记每个 URL 的状态（通过 / 失败）
  /// - 如果发生自动迁移，更新 [_currentBaseUrl] 显示最新地址
  /// - 调 [widget.onSwitched] 通知外层 settings page 同步
  Future<void> _autoTestMirrors() async {
    if (!mounted) return;
    setState(() {
      _autoTestingMirrors = true;
      _mirrorStatus.clear();
    });

    // 串行测试每个镜像（避免并发触发反爬）
    final mirrors = List<String>.from(ApiServerSwitcher.presetMirrors);
    String? lastMigratedUrl;

    for (final mirror in mirrors) {
      if (!mounted) return;
      final before = ApiServerSwitcher.current;
      final result = await ApiServerSwitcher.testConnectivity(mirror);
      final after = ApiServerSwitcher.current;

      // 判断此镜像是否可用：
      // - testConnectivity 返回 null → 通过（真实源站 或 已自动迁移到最新）
      // - 比较测试前后 current：若不同则说明触发了迁移，新地址已加入镜像列表
      final migrated = after != before;
      if (migrated && lastMigratedUrl == null) {
        lastMigratedUrl = after;
      }
      if (!mounted) return;
      setState(() {
        _mirrorStatus[mirror] = (result == null);
        // 如果发生了迁移，把新地址标记为通过
        if (migrated) {
          _mirrorStatus[after] = true;
        }
      });
    }

    if (!mounted) return;
    setState(() {
      _autoTestingMirrors = false;
      // 如果发生迁移，更新当前 URL 显示为最新地址
      final newCurrent = ApiServerSwitcher.current;
      if (newCurrent != _currentBaseUrl) {
        _currentBaseUrl = newCurrent;
      }
    });

    // 如果发生自动迁移，通知外层 settings page 同步
    if (lastMigratedUrl != null) {
      widget.onSwitched();
    }
  }

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
                  // 自动测试状态提示
                  if (_autoTestingMirrors) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: DesignTokens.spaceXs),
                        Text(
                          '正在自动测试镜像列表...',
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // 测试结果：成功（含自动迁移）/ 失败
                  if (_hasTested && _testResult == null) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      _originalBaseUrlBeforeTest != null &&
                              _originalBaseUrlBeforeTest != _currentBaseUrl
                          ? '连接成功，已自动迁移到 $_currentBaseUrl'
                          : '连接成功',
                      style: TextStyle(
                        fontSize: DesignTokens.textCaption,
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (_testResult != null) ...[
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

                  // 镜像列表（含每个 URL 的状态徽章）
                  _buildSubLabel('镜像列表'),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Wrap(
                    spacing: DesignTokens.spaceSm,
                    runSpacing: DesignTokens.spaceSm,
                    children: ApiServerSwitcher.presetMirrors.map((url) {
                      final selected = url == _currentBaseUrl;
                      final status = _mirrorStatus[url];
                      return _MirrorChip(
                        url: url,
                        selected: selected,
                        status: status,
                        autoTesting: _autoTestingMirrors,
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
                      // 内部直接弹自定义 URL 输入框，避免 sheet pop + dialog push 竞争闪退
                      onPressed: () async {
                        final result = await _showCustomUrlDialog();
                        if (result != null &&
                            result.isNotEmpty &&
                            result != _currentBaseUrl) {
                          await _switchBaseUrl(result);
                        }
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
    _originalBaseUrlBeforeTest = _currentBaseUrl;
    setState(() {
      _testingUrl = true;
      _testResult = null;
    });
    final result = await ApiServerSwitcher.testConnectivity(_currentBaseUrl);
    if (!mounted) return;
    // 测试可能触发跳转壳自动迁移 → 读取 ApiServerSwitcher.current 显示最新地址
    // （如：用户测 http://555973.xyz，跳转壳指向 http://555980.xyz → switchTo 已持久化）
    final newBaseUrl = ApiServerSwitcher.current;
    final migrated = newBaseUrl != _originalBaseUrlBeforeTest;
    setState(() {
      _testingUrl = false;
      _currentBaseUrl = newBaseUrl;
      // 若发生自动迁移 + 测试成功 → _testResult 留空，UI 显示"已自动迁移到 xxx"
      // 若迁移后仍失败 → 显示"已迁移到 xxx，但 <错误信息>"
      if (migrated && result != null) {
        _testResult = '已迁移到 $newBaseUrl，但 $result';
      } else {
        _testResult = result;
      }
      _hasTested = true;
      // 同步镜像列表的状态：当前 URL 标记为通过 / 失败
      if (result == null) {
        _mirrorStatus[newBaseUrl] = true;
      } else if (_originalBaseUrlBeforeTest != null) {
        _mirrorStatus[_originalBaseUrlBeforeTest!] = false;
      }
    });
    // 若发生自动迁移，通知外层 settings page 同步「API 服务器」行的 URL 显示
    if (migrated) {
      widget.onSwitched();
    }
  }

  /// 自定义 URL 输入框（在 sheet 内部使用 sheet 自己的 context）
  ///
  /// **重要设计**：之前是 sheet 关闭后调用 `Get.dialog` 依赖 Get.context，
  /// 但 sheet pop 与 Get.dialog push 之间存在 race condition（GetX 的 overlayContext
  /// 在 sheet 关闭动画期间可能未就绪），导致"自定义 API 服务器卡住且闪退"。
  ///
  /// 现在改为：sheet 保持打开，用 `showDialog(context: context)` 直接 push
  /// 到 sheet 的 Navigator 上方，dialog 关闭后 sheet 仍然存在。
  /// 用户确认 → 调用方切换 baseUrl 并关闭 sheet；用户取消 → sheet 保持。
  Future<String?> _showCustomUrlDialog() async {
    final controller = TextEditingController(text: _currentBaseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        title: Text(
          '自定义 API URL',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: DesignTokens.textH2,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: 'http://example.com',
            hintStyle: TextStyle(color: colors.onSurfaceMuted),
            filled: true,
            fillColor: colors.surfaceVariant,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: colors.onSurfaceMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
///
/// 视觉状态：
/// - **selected**：当前选中的 URL（primary 边框 + 对勾）
/// - **status**：
///   - true：通过（绿色对勾小徽章）
///   - false：失败（红色叉小徽章）
///   - null：未测试（无徽章）
/// - **autoTesting**：批量测试进行中，显示小型 loading 圈
class _MirrorChip extends StatelessWidget {
  final String url;
  final bool selected;
  final bool? status;
  final bool autoTesting;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _MirrorChip({
    required this.url,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.status,
    this.autoTesting = false,
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
              // 状态徽章（选中状态时不显示，避免与对勾重复）
              if (!selected) ...[
                const SizedBox(width: 4),
                _buildStatusBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 状态徽章：通过 / 失败 / 测试中
  Widget _buildStatusBadge() {
    if (autoTesting && status == null) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    if (status == true) {
      return Icon(
        PhosphorIconsFill.checkCircle,
        size: 11,
        color: colors.success,
      );
    }
    if (status == false) {
      return Icon(
        PhosphorIconsFill.xCircle,
        size: 11,
        color: colors.destructive,
      );
    }
    return const SizedBox.shrink();
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
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  /// 判断颜色是否为浅色（用于决定按钮文字颜色）
  static bool _isLight(Color color) {
    // 标准亮度公式：0.299R + 0.587G + 0.114B（归一化到 0-1）
    final luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.6;
  }
}
