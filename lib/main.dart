import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videohub/presentation/bindings/app_binding.dart';
import 'package:videohub/presentation/pages/main_shell.dart';

/// 应用入口
///
/// 启动流程：
/// 1. WidgetsFlutterBinding.ensureInitialized()
/// 2. initializeApp() — 异步初始化 Dio / DB / Repository / Controller
/// 3. runApp(MainShell())
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeApp();

  runApp(const MainShell());
}
