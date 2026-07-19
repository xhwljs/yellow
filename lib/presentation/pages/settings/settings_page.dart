import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/network/dio_client.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_controller.dart';
import 'package:videohub/core/theme/theme_presets.dart';

/// 设置页
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 第一组：主题色（5 个色块横排，pink/red/blue/purple/orange）
/// - 当前选中色块带 border + checkmark
/// - 第二组：关于（App 名、版本号、技术栈）
/// - 第三组：清除缓存按钮，调用 DioClient.clearCookies() 并提示成功
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        children: [
          _buildThemeSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildAboutSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildCacheSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
        ],
      ),
    );
  }

  /// 第一组：主题色
  Widget _buildThemeSection(colors) {
    final themeController = Get.find<ThemeController>();
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.palette(),
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                '主题色',
                style: TextStyle(
                  fontSize: DesignTokens.textH2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            '切换主题色，背景保持浅色不变',
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
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
                  onTap: () =>
                      themeController.switchPreset(preset),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: DesignTokens.spaceLg),
          Obx(() {
            final current = themeController.presetRx.value;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
                vertical: DesignTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info(),
                    size: 14,
                    color: colors.onSurfaceMuted,
                  ),
                  const SizedBox(width: DesignTokens.spaceXs),
                  Text(
                    '当前：${current.name} · ${current.description}',
                    style: TextStyle(
                      fontSize: DesignTokens.textCaption,
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 第二组：关于
  Widget _buildAboutSection(colors) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.info(),
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                '关于',
                style: TextStyle(
                  fontSize: DesignTokens.textH2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          _buildInfoRow(colors, '应用名称', AppConstants.appName),
          const Divider(height: DesignTokens.spaceLg),
          _buildInfoRow(colors, '当前版本', 'v${AppConstants.appVersion}'),
          const Divider(height: DesignTokens.spaceLg),
          _buildInfoRow(colors, '技术栈', 'Flutter + GetX + Floor'),
          const Divider(height: DesignTokens.spaceLg),
          _buildInfoRow(colors, '设计系统', 'VideoHub MASTER v1.0'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    );
  }

  /// 第三组：清除缓存
  Widget _buildCacheSection(colors) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.trash(),
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                '缓存',
                style: TextStyle(
                  fontSize: DesignTokens.textH2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            '清理 Cookie / Session 缓存数据',
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _clearCache,
              icon: Icon(PhosphorIconsRegular.broom()),
              label: const Text('清除缓存'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.destructive,
                foregroundColor: colors.surface,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLg,
                  vertical: DesignTokens.spaceMd,
                ),
              ),
            ),
          ),
        ],
      ),
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

/// 主题色色块
class _ThemeColorBlock extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final colors;
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
                        PhosphorIconsFill.check(),
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
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.onBackground : colors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
