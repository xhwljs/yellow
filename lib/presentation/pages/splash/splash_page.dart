import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

// 默认主题色（pink）— 与 ThemePreset.pink 一致
// 启动时 ThemeController 尚未就绪，硬编码默认主题色避免依赖 GetX
const Color _kPrimaryColor = Color(0xFFEC4899);
const Color _kBackgroundColor = Color(0xFFF5F5F7);
const Color _kOnBackgroundColor = Color(0xFF1A1A1A);
const Color _kOnBackgroundMutedColor = Color(0xFF8E8E93);

/// 启动页（Splash Screen）
///
/// App 启动时首先显示此页面，给用户即时视觉反馈，避免黑屏。
/// 在此期间后台执行 [initializeApp]（加载 baseUrl / Dio / DB / Controller）。
///
/// 设计要点：
/// - **背景色**：与 App 主题背景一致 (#F5F5F7)，避免从 native 黑屏到 App 浅色背景的突兀跳变
/// - **Logo**：phosphor FilmSlate 图标（视频聚合主题）+ 圆角卡片容器
/// - **App 名称**：Poppins 字体（与 design-system MASTER.md body 字体一致）
/// - **加载指示**：底部 CircularProgressIndicator + 文案
/// - **沉浸状态栏**：透明状态栏，让 splash 内容延伸到顶部
///
/// 由于启动时 ThemeController 尚未初始化，使用固定的 pink 主题色（默认主题）
/// 完成后切换到 MainShell 时会读取用户保存的主题。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

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
      home: const _SplashBody(),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  /// Logo：圆角卡片容器 + phosphor FilmSlate 图标
  ///
  /// 设计：
  /// - 96×96 圆角卡片（radiusLg）
  /// - 主题色渐变背景
  /// - 白色 FilmSlate 图标（视频聚合主题）
  /// - elevation2 阴影
  Widget _buildLogo() {
    return Container(
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
  /// 主题色 CircularProgressIndicator + 加载文案
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
        Text(
          '正在加载...',
          style: GoogleFonts.poppins(
            fontSize: DesignTokens.textCaption,
            color: _kOnBackgroundMutedColor,
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
