import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';

/// 主题控制器 — 全局主题色切换（预设 + 自定义色）
///
/// 严格遵循 MASTER.md §3：
/// - 仅浅色模式
/// - 通过切换 ThemePreset 实现「主题色切换」
/// - 持久化到 SharedPreferences：
///   * [AppConstants.keyThemePreset]：当前预设 id（'pink' / 'red' / ... / 'custom'）
///   * [AppConstants.keyCustomPrimaryColor]：自定义模式下的 primary 色 ARGB int 值
class ThemeController extends GetxController {
  ThemeController({SharedPreferences? prefs}) : _prefs = prefs;

  final Rx<ThemePreset> _preset = ThemePreset.pink.obs;
  final Rx<Color> _customColor = const Color(0xFFEC4899).obs;
  final RxBool _initialized = false.obs;

  SharedPreferences? _prefs;

  Rx<ThemePreset> get presetRx => _preset;
  ThemePreset get preset => _preset.value;

  /// 自定义颜色（仅 preset == ThemePreset.custom 时被使用）
  Rx<Color> get customColorRx => _customColor;
  Color get customColor => _customColor.value;

  /// 当前生效的 ThemeColors（合并 preset 与 customColor）
  ThemeColors get colors => ThemeColors(_preset.value, customPrimary: _customColor.value);

  bool get isReady => _initialized.value;

  @override
  void onInit() {
    super.onInit();
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    _prefs ??= await SharedPreferences.getInstance();
    final id = _prefs!.getString(AppConstants.keyThemePreset);
    _preset.value = ThemePreset.fromId(id);

    // 加载自定义颜色（仅当上次是 custom 模式时才有效）
    final customArgb = _prefs!.getInt(AppConstants.keyCustomPrimaryColor);
    if (customArgb != null) {
      _customColor.value = Color(customArgb);
    }
    _initialized.value = true;
    _applyTheme();
  }

  /// 切换到预设主题色
  Future<void> switchPreset(ThemePreset newPreset) async {
    if (newPreset == _preset.value) return;
    _preset.value = newPreset;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(AppConstants.keyThemePreset, newPreset.id);
    _applyTheme();
    Get.snackbar(
      '主题已切换',
      '当前主题：${newPreset.name}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// 切换到自定义颜色（自动切到 custom 预设）
  ///
  /// [color] 用户从 HSV 选色盘选定的颜色。
  /// 同时写入 preset=custom 和 customColor 两个 SP key。
  Future<void> applyCustomColor(Color color) async {
    _customColor.value = color;
    _preset.value = ThemePreset.custom;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(AppConstants.keyThemePreset, ThemePreset.custom.id);
    await _prefs!.setInt(AppConstants.keyCustomPrimaryColor, color.value);
    _applyTheme();
    Get.snackbar(
      '主题已切换',
      '当前主题：自定义',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _applyTheme() {
    Get.changeTheme(AppTheme.fromPreset(_preset.value, customPrimary: _customColor.value));
  }
}
