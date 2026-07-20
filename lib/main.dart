import 'package:flutter/material.dart';
import 'package:yellow_depot/presentation/bindings/app_binding.dart';
import 'package:yellow_depot/presentation/pages/main_shell.dart';
import 'package:yellow_depot/presentation/pages/splash/splash_page.dart';

/// 应用入口
///
/// 启动流程：
/// 1. WidgetsFlutterBinding.ensureInitialized()
/// 2. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 3. 后台异步执行 initializeApp() — 加载 baseUrl / Dio / DB / Controller
/// 4. 完成后 runApp(MainShell()) — 替换为正式 App
///
/// **启动页作用**：
/// - 给用户即时视觉反馈（App logo + 加载指示）
/// - 避免冷启动时白屏/黑屏
/// - 在后台完成必要的异步初始化（数据库、网络、主题加载）
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 先显示启动页（同步立即渲染，避免黑屏）
  runApp(const SplashPage());

  // 2. 后台执行异步初始化
  await initializeApp();

  // 3. 完成后切换到正式 App
  runApp(const MainShell());
}
