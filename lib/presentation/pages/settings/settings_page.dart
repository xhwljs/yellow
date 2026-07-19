import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/network/api_server_switcher.dart';
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
/// - 第二组：API 服务器（运行时切换 baseUrl，含连通性测试）
/// - 第三组：关于（App 名、版本号、技术栈）
/// - 第四组：清除缓存按钮，调用 DioClient.clearCookies() 并提示成功
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
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        children: [
          _buildThemeSection(colors),
          const SizedBox(height: DesignTokens.spaceXl),
          _buildApiServerSection(colors),
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
                PhosphorIconsRegular.palette,
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
                  onTap: () => themeController.switchPreset(preset),
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
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info,
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

  /// 第二组：API 服务器切换
  Widget _buildApiServerSection(colors) {
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
                PhosphorIconsRegular.globe,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                'API 服务器',
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
            '源站域名会因反爬频繁更换，如遇加载失败可切换镜像',
            style: TextStyle(
              fontSize: DesignTokens.textCaption,
              color: colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          // 当前 baseUrl 显示
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
              vertical: DesignTokens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: Row(
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
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 14,
                    color: colors.destructive,
                  ),
              ],
            ),
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
          ] else if (!_testingUrl && _testResult == null && _hasTested) ...[
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              '连接正常',
              style: TextStyle(
                fontSize: DesignTokens.textCaption,
                color: colors.primary,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spaceLg),
          // 镜像列表
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
          // 测试当前连通性
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testingUrl ? null : _testConnectivity,
              icon: const Icon(PhosphorIconsRegular.plugsConnected),
              label: const Text('测试连通性'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
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
          const SizedBox(height: DesignTokens.spaceSm),
          // 自定义 URL 输入
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCustomUrlDialog,
              icon: const Icon(PhosphorIconsRegular.pencilSimpleLine),
              label: const Text('自定义 URL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurfaceMuted,
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
          const SizedBox(height: DesignTokens.spaceSm),
          // 重置为默认
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

  /// 第三组：关于
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
                PhosphorIconsRegular.info,
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
                PhosphorIconsRegular.trash,
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
      color: selected ? colors.primary.withOpacity(0.1) : colors.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSm,
            vertical: DesignTokens.spaceXs,
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
