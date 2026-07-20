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

/// 设置页（重构版）
///
/// 设计原则（应用 ui-ux-pro-max App UI 指引）：
/// - **Section Card 模式**：每个分组都是 elevation1 圆角卡片，统一节奏
/// - **SectionHeader 复用组件**：彩色 icon chip + 标题 + 副标题
/// - **SettingsRow 复用组件**：iOS 风格 label-value 行，统一 Divider 分隔
/// - **状态徽章**：语义色 pill badge（success / destructive）
/// - **操作层级**：主操作 FilledButton（高亮），次操作 OutlinedButton，
///   三级操作 TextButton（去强调），让用户视觉焦点集中在最重要的操作
/// - **App Hero Header**：顶部 logo + 名称 + 版本作为视觉锚点
/// - **触控目标 ≥48dp**（所有按钮 minimumSize: Size(48, 48)）
///
/// 功能与旧版完全一致，仅改进视觉层次和交互清晰度：
/// - 主题色选择（5 个预设 + 当前预设徽章）
/// - API 服务器切换（当前 URL + 镜像 chips + 测试连通性 + 自定义 URL + 重置）
/// - 关于（应用名/版本/技术栈/设计系统）
/// - 清除缓存
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentBaseUrl = ApiServerSwitcher.current;
  bool _testingUrl = false;
  String? _testResult;
  bool _hasTested = false;

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
          _buildAppHero(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildThemeSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildApiServerSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildAboutSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildCacheSection(colors),
        ],
      ),
    );
  }

  // ============================================================
  // App Hero Header — 顶部视觉锚点
  // ============================================================
  //
  // 设计：
  // - 主题色渐变背景的圆角卡片，96x96 logo
  // - logo（FilmSlate 图标）+ App 名（Poppins display 字体）+ 版本号
  // - 整体作为视觉锚点，让用户进入设置页时立即看到 app 标识
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
  // Section 1: 主题色
  // ============================================================
  Widget _buildThemeSection(ThemeColors colors) {
    final themeController = Get.find<ThemeController>();
    return _SectionCard(
      colors: colors,
      header: _SectionHeader(
        icon: PhosphorIconsRegular.palette,
        title: '主题色',
        subtitle: '切换主题色，背景保持浅色不变',
        colors: colors,
      ),
      children: [
        Obx(() {
          final current = themeController.presetRx.value;
          return Wrap(
            spacing: DesignTokens.spaceLg,
            runSpacing: DesignTokens.spaceLg,
            children: ThemePreset.values.map((preset) {
              final selected = preset == current;
              return _ThemeColorBlock(
                preset: preset,
                selected: selected,
                colors: colors,
                onTap: () => themeController.switchPreset(preset),
              );
            }).toList(),
          );
        }),
        const SizedBox(height: DesignTokens.spaceLg),
        Obx(() {
          final current = themeController.presetRx.value;
          return _StatusBadge(
            text: '当前：${current.name} · ${current.description}',
            icon: PhosphorIconsRegular.info,
            tone: _StatusTone.neutral,
            colors: colors,
          );
        }),
      ],
    );
  }

  // ============================================================
  // Section 2: API 服务器
  // ============================================================
  Widget _buildApiServerSection(ThemeColors colors) {
    return _SectionCard(
      colors: colors,
      header: _SectionHeader(
        icon: PhosphorIconsRegular.globe,
        title: 'API 服务器',
        subtitle: '源站域名会因反爬频繁更换，如遇加载失败可切换镜像',
        colors: colors,
      ),
      children: [
        // 当前 baseUrl + 连通状态徽章
        Row(
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
        ),
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

        // 镜像列表 section label
        _SubLabel(text: '镜像列表', colors: colors),
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
        // 主操作：测试连通性（FilledButton，主色调高亮）
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
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSm),

        // 次操作：自定义 URL（OutlinedButton，去强调但可见）
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCustomUrlDialog,
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
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXs),

        // 三级操作：重置为默认（TextButton，最弱强调）
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
    );
  }

  Future<void> _switchBaseUrl(String newUrl) async {
    final colors = AppTheme.colorsOf(Get.context!);
    try {
      await ApiServerSwitcher.switchTo(newUrl);
      setState(() {
        _currentBaseUrl = newUrl;
        _testResult = null;
        _hasTested = false;
      });
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

  // ============================================================
  // Section 3: 关于
  // ============================================================
  Widget _buildAboutSection(ThemeColors colors) {
    return _SectionCard(
      colors: colors,
      header: _SectionHeader(
        icon: PhosphorIconsRegular.info,
        title: '关于',
        subtitle: null,
        colors: colors,
      ),
      children: [
        _SettingsRow(
          label: '应用名称',
          value: AppConstants.appName,
          colors: colors,
        ),
        _Divider(colors: colors),
        _SettingsRow(
          label: '当前版本',
          value: 'v${AppConstants.appVersion}',
          colors: colors,
        ),
        _Divider(colors: colors),
        _SettingsRow(
          label: '技术栈',
          value: 'Flutter + GetX + Floor',
          colors: colors,
        ),
        _Divider(colors: colors),
        _SettingsRow(
          label: '设计系统',
          value: 'Yellow Depot MASTER v1.0',
          colors: colors,
        ),
      ],
    );
  }

  // ============================================================
  // Section 4: 缓存
  // ============================================================
  Widget _buildCacheSection(ThemeColors colors) {
    return _SectionCard(
      colors: colors,
      header: _SectionHeader(
        icon: PhosphorIconsRegular.trash,
        title: '缓存',
        subtitle: '清理 Cookie / Session 缓存数据',
        colors: colors,
      ),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _clearCache,
            icon: const Icon(PhosphorIconsRegular.broom),
            label: const Text('清除缓存'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.destructive,
              foregroundColor: colors.surface,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceLg,
                vertical: DesignTokens.spaceMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
            ),
          ),
        ),
      ],
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

/// 状态徽章色调
enum _StatusTone { success, destructive, neutral }

/// 通用 Section Card
///
/// - elevation1 圆角卡片
/// - 顶部 header（icon chip + 标题 + 副标题）
/// - 内容区按需填充 children
class _SectionCard extends StatelessWidget {
  final ThemeColors colors;
  final _SectionHeader header;
  final List<Widget> children;

  const _SectionCard({
    required this.colors,
    required this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (children.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceLg),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// Section Header
///
/// 设计：
/// - 左侧 36x36 彩色 icon chip（primary.withOpacity(0.12) 背景 + primary 图标）
/// - 右侧 标题（H2 600）+ 副标题（caption muted，可选）
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final ThemeColors colors;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: colors.primary,
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
                  fontSize: DesignTokens.textH2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
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
      ],
    );
  }
}

/// 子区块标签（如 "镜像列表"）
class _SubLabel extends StatelessWidget {
  final String text;
  final ThemeColors colors;

  const _SubLabel({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
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
}

/// Settings Row — iOS 风格的 label-value 行
///
/// - 左侧 label（onSurfaceMuted）
/// - 右侧 value（onSurface，可 ellipsis）
/// - 适合"关于"等纯信息展示场景
class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeColors colors;

  const _SettingsRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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

/// 分割线
class _Divider extends StatelessWidget {
  final ThemeColors colors;
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.border.withOpacity(0.6),
    );
  }
}

/// 状态徽章（pill badge）
///
/// 设计：
/// - pill 形状（radiusPill）
/// - 三种色调：success（绿）/ destructive（红）/ neutral（灰）
/// - icon + 文本紧凑布局
/// - compact=true 时缩小尺寸用于行内嵌入
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
      _StatusTone.neutral =>
        (colors.onSurfaceMuted, colors.surfaceVariant),
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
          Icon(
            icon,
            size: compact ? 11 : 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? DesignTokens.textLabel : DesignTokens.textCaption,
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

/// 主题色色块
class _ThemeColorBlock extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ThemeColorBlock({
    required this.preset,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colors.onBackground : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: preset.primaryColor,
                shape: BoxShape.circle,
                boxShadow: DesignTokens.elevation1,
              ),
              child: selected
                  ? Center(
                      child: Icon(
                        PhosphorIconsFill.check,
                        color: colors.surface,
                        size: 24,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            preset.name,
            style: TextStyle(
              fontSize: DesignTokens.textLabel,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.onBackground : colors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
