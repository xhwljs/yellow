import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:yellow_depot/presentation/pages/splash/splash_page.dart';

/// 应用入口
///
/// 启动流程（详见 [SplashPage] 文档）：
/// 1. WidgetsFlutterBinding.ensureInitialized()
/// 2. WakelockPlus.enable() — App 在前台时一直保持屏幕常亮
/// 3. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 4. SplashPage 内部启动后台初始化任务：
///    - initializeApp()（数据 / 网络 / 主题）
///    - GitHubReleaseService.checkForUpdate()（并行检查更新）
///    - 等待至少 2 秒（避免快速加载导致闪屏）
/// 5. 有新版本 → 显示 UpdateDialog
///    无新版本 → 切换到 MainShell
///
/// **屏幕常亮说明**：
/// 之前在 PlayerPageController.onInit 中开启 wakelock，但用户反馈还是会息屏
/// （可能因为生命周期管理复杂，切后台再回来时 wakelock 失效）。
/// 现在改为 App 全局常亮：
/// - FLAG_KEEP_SCREEN_ON 只对前台 activity 有效，App 切到后台后系统会
///   自动息屏，不会浪费电
/// - App 在前台时任何页面都常亮，避免播放页生命周期管理导致 wakelock 失效
/// - wakelock_plus 无需 WAKE_LOCK 权限（使用 WindowManager flag）
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // App 在前台时一直保持屏幕常亮
  WakelockPlus.enable();

  // 直接 runApp SplashPage — 同步立即渲染，避免黑屏
  // 初始化逻辑在 SplashPage 内部执行（StatefulWidget initState 触发）
  runApp(const SplashPage());
}
