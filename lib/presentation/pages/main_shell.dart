import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_controller.dart';
import 'package:videohub/presentation/controllers/main_shell_controller.dart';
import 'package:videohub/presentation/pages/favorites/favorites_page.dart';
import 'package:videohub/presentation/pages/history/history_page.dart';
import 'package:videohub/presentation/pages/home/home_page.dart';
import 'package:videohub/presentation/pages/settings/settings_page.dart';
import 'package:videohub/presentation/routes/app_pages.dart';

/// 主 Shell — GetMaterialApp 入口 + 底部导航
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 仅浅色模式（#F5F5F7 背景）
/// - 通过 Obx 监听 ThemeController.presetRx 实现主题色切换
/// - 4 Tab：首页 / 收藏 / 历史 / 设置
/// - IndexedStack 保持状态
class MainShell extends GetView<MainShellController> {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final preset = themeController.presetRx.value;
      return GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.fromPreset(preset),
        defaultTransition: Transition.fadeIn,
        transitionDuration: DesignTokens.motionSlow,
        home: const _ShellBody(),
        getPages: AppPages.routes,
      );
    });
  }
}

/// Shell 主体 — Scaffold + BottomNavigationBar + IndexedStack
class _ShellBody extends GetView<MainShellController> {
  const _ShellBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Obx(() {
      final index = controller.currentIndex.value;
      return Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomePage(),
            FavoritesPage(),
            HistoryPage(),
            SettingsPage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: controller.changeTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.surface,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.onSurfaceMuted,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.house()),
              activeIcon: Icon(PhosphorIconsFill.house()),
              label: '首页',
              tooltip: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.heart()),
              activeIcon: Icon(PhosphorIconsFill.heart()),
              label: '收藏',
              tooltip: '收藏',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.clock()),
              activeIcon: Icon(PhosphorIconsFill.clock()),
              label: '历史',
              tooltip: '历史',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.gear()),
              activeIcon: Icon(PhosphorIconsFill.gear()),
              label: '设置',
              tooltip: '设置',
            ),
          ],
        ),
      );
    });
  }
}
