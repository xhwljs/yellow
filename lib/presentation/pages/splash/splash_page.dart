import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/presentation/bindings/app_binding.dart';
import 'package:yellow_depot/presentation/pages/main_shell.dart';
import 'package:yellow_depot/presentation/widgets/update_dialog.dart';

/// 默认主题色（pink）— 与 ThemePreset.pink 一致
///
/// 启动时 ThemeController 尚未就绪，硬编码默认主题色避免依赖 GetX。
/// 加载完成后切换到 MainShell 时会读取用户保存的主题。
const Color _kPrimaryColor = Color(0xFFEC4899);
const Color _kBackgroundColor = Color(0xFFF5F5F7);
const Color _kOnBackgroundColor = Color(0xFF1A1A1A);
const Color _kOnBackgroundMutedColor = Color(0xFF8E8E93);

/// 启动页（Splash Screen）
///
/// 启动流程：
/// 1. WidgetsFlutterBinding.ensureInitialized（在 main.dart 完成）
/// 2. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 3. 启动页内部启动后台初始化任务：
///    a. initializeApp()（加载 baseUrl / Dio / DB / Controller）
///    b. GitHubReleaseService.checkForUpdate()（并行检查更新）
///    c. 等待 (a) 完成 + 显示至少 2 秒（避免加载太快闪屏）
/// 4. (a)(b)(c) 全部完成：
///    - 有新版本 → 弹出 UpdateDialog，用户决定是否更新
///    - 无新版本或检查失败 → 直接切换到 MainShell
/// 5. 用户在 UpdateDialog 选"稍后" → 切换到 MainShell
/// 6. 用户在 UpdateDialog 选"立即更新" → 下载并唤起系统 APK 安装器
///    （安装器打开后用户回到桌面手动安装，splash 页保持显示）
///
/// 设计要点：
/// - **背景色**：与 App 主题背景一致 (#F5F5F7)，避免从 native 黑屏到 App 浅色背景的突兀跳变
/// - **Logo**：phosphor FilmSlate 图标（视频聚合主题）+ 圆角卡片容器
/// - **App 名称**：Poppins 字体（与 design-system MASTER.md body 字体一致）
/// - **加载指示**：底部 CircularProgressIndicator + 状态文案（动态显示当前阶段）
/// - **沉浸状态栏**：透明状态栏，让 splash 内容延伸到顶部
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// 当前加载阶段文案（动态更新）
  String _loadingText = '正在加载...';

  @override
  void initState() {
    super.initState();
    // 异步启动整个初始化流程（不阻塞首次 build）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupSequence();
    });
  }

  /// 启动序列：initializeApp + checkForUpdate + 最小展示 2 秒
  Future<void> _runStartupSequence() async {
    final stopwatch = Stopwatch()..start();

    // 阶段 1：初始化（数据 / 网络 / 主题）
    setState(() => _loadingText = '正在加载应用数据...');
    try {
      await initializeApp();
    } catch (e) {
      // 初始化失败仍然继续进入 App（用户可手动重试）
      debugPrint('initializeApp failed: $e');
    }

    // 阶段 2：检查更新（与剩余最小展示时间并行）
    setState(() => _loadingText = '正在检查更新...');
    GitHubRelease? update;
    try {
      update = await GitHubReleaseService.checkForUpdate();
    } catch (e) {
      debugPrint('checkForUpdate failed: $e');
    }

    // 阶段 3：保证 splash 至少展示 2 秒（避免快速加载导致闪屏）
    final minSplashDuration = const Duration(seconds: 2);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }

    // 阶段 4：进入下一步
    if (!mounted) return;

    if (update != null) {
      // 有新版本 → 显示更新对话框
      setState(() => _loadingText = '发现新版本');
      await UpdateDialog.show(
        context,
        release: update,
        onLater: _enterApp,
      );
      // 注意：用户点"立即更新"会唤起系统 APK 安装器，
      // 安装器返回后用户回到 App 仍然停留在 splash 页。
      // 此处不主动 _enterApp，让用户在安装完成后从桌面再次启动。
    } else {
      // 无新版本或检查失败 → 直接进入 App
      _enterApp();
    }
  }

  /// 切换到 MainShell
  void _enterApp() {
    if (!mounted) return;
    runApp(const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _kBackgroundColor,
        colorScheme: const ColorScheme.light(
          primary: _kPrimaryColor,
          surface: _kBackgroundColor,
        ),
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: _kBackgroundColor,
          body: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo 区域：圆角卡片容器 + FilmSlate 图标
                  _buildLogo(),
                  const SizedBox(height: DesignTokens.spaceXl),
                  // App 名称
                  _buildAppName(),
                  const SizedBox(height: DesignTokens.spaceXs),
                  // 副标题
                  _buildSubtitle(),
                  const Spacer(flex: 3),
                  // 加载指示器
                  _buildLoadingIndicator(),
                  const SizedBox(height: DesignTokens.spaceXl),
                  // 版本号
                  _buildVersion(),
                  const SizedBox(height: DesignTokens.space2xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo：圆角卡片容器 + phosphor FilmSlate 图标 + 渐变光晕
  ///
  /// 设计：
  /// - 96×96 圆角卡片（radiusLg）
  /// - 主题色渐变背景
  /// - 白色 FilmSlate 图标（视频聚合主题）
  /// - elevation2 阴影
  /// - 外层光晕动画（呼吸效果，让 splash 更有"生命力"）
  Widget _buildLogo() {
    return TweenAnimationBuilder<double>(
      tween: const Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEC4899), // pink primary
              Color(0xFFDB2777), // pink secondary
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryColor.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            PhosphorIconsFill.filmSlate,
            size: 48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// App 名称
  ///
  /// 使用 Poppins 字体（与项目其他地方一致，避免启动阶段 display 字体未加载）
  /// 28px Bold，深色文本
  Widget _buildAppName() {
    return Text(
      AppConstants.appName,
      style: GoogleFonts.poppins(
        fontSize: DesignTokens.textDisplay,
        fontWeight: FontWeight.w700,
        color: _kOnBackgroundColor,
        letterSpacing: 0.5,
      ),
    );
  }

  /// 副标题
  Widget _buildSubtitle() {
    return Text(
      '视频聚合 · 随心播放',
      style: GoogleFonts.poppins(
        fontSize: DesignTokens.textBody,
        fontWeight: FontWeight.w400,
        color: _kOnBackgroundMutedColor,
        letterSpacing: 0.3,
      ),
    );
  }

  /// 加载指示器
  ///
  /// 主题色 CircularProgressIndicator + 动态加载文案
  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: _kPrimaryColor,
            strokeWidth: 2.5,
            backgroundColor: _kPrimaryColor.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: GoogleFonts.poppins(
              fontSize: DesignTokens.textCaption,
              color: _kOnBackgroundMutedColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 版本号
  Widget _buildVersion() {
    return Text(
      'v${AppConstants.appVersion}',
      style: GoogleFonts.poppins(
        fontSize: DesignTokens.textLabel,
        color: _kOnBackgroundMutedColor.withOpacity(0.7),
      ),
    );
  }
}
