import 'package:flutter/material.dart';
import 'package:yellow_depot/presentation/pages/splash/splash_page.dart';

/// 应用入口
///
/// 启动流程（详见 [SplashPage] 文档）：
/// 1. WidgetsFlutterBinding.ensureInitialized()
/// 2. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 3. SplashPage 内部启动后台初始化任务：
///    - initializeApp()（数据 / 网络 / 主题）
///    - GitHubReleaseService.checkForUpdate()（并行检查更新）
///    - 等待至少 2 秒（避免快速加载导致闪屏）
/// 4. 有新版本 → 显示 UpdateDialog
///    无新版本 → 切换到 MainShell
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 直接 runApp SplashPage — 同步立即渲染，避免黑屏
  // 初始化逻辑在 SplashPage 内部执行（StatefulWidget initState 触发）
  runApp(const SplashPage());
}
