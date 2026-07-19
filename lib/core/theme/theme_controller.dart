import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/theme_presets.dart';

/// 主题控制器 — 全局主题色切换
///
/// 严格遵循 MASTER.md §3：
/// - 仅浅色模式
/// - 通过切换 ThemePreset 实现「主题色切换」
/// - 持久化到 SharedPreferences
class ThemeController extends GetxController {
  ThemeController({SharedPreferences? prefs}) : _prefs = prefs;

  final Rx<ThemePreset> _preset = ThemePreset.pink.obs;
  final RxBool _initialized = false.obs;

  SharedPreferences? _prefs;

  Rx<ThemePreset> get presetRx => _preset;
  ThemePreset get preset => _preset.value;
  ThemeColors get colors => ThemeColors(_preset.value);
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
    _initialized.value = true;
    _applyTheme();
  }

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

  void _applyTheme() {
    Get.changeTheme(AppTheme.fromPreset(_preset.value));
  }
}
