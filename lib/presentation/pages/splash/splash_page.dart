import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/api_server_switcher.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/presentation/bindings/app_binding.dart';
import 'package:yellow_depot/presentation/pages/main_shell.dart';
import 'package:yellow_depot/presentation/widgets/update_dialog.dart';

/// 默认主题色（pink）— 引用设计系统单一真理源
///
/// 启动时 ThemeController 尚未就绪，这里引用 [ThemePreset.defaultPrimaryColor]
/// 等 static const 常量（Dart 限制枚举实例属性无法在 const 上下文访问），
/// 与 [DesignTokens] 的 const 常量（不依赖 GetX）。加载完成后切换到
/// MainShell 时会读取用户保存的主题。
const Color _kPrimaryColor = ThemePreset.defaultPrimaryColor;
const Color _kBackgroundColor = DesignTokens.colorBackground;
const Color _kOnBackgroundColor = DesignTokens.colorOnBackground;
const Color _kOnBackgroundMutedColor = DesignTokens.colorOnSurfaceMuted;

/// 启动页"获取最新域名"状态
enum _DomainStatus {
  /// 未开始 / 常规加载（显示加载指示器 + 阶段文案）
  pending,

  /// 获取成功（显示成功图标 + 获取到的新域名）
  success,

  /// 获取失败（显示失败提示，随后正常进入 App）
  failure,
}

/// 启动页（Splash Screen）
///
/// 启动流程：
/// 1. WidgetsFlutterBinding.ensureInitialized（在 main.dart 完成）
/// 2. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 3. 启动页内部启动后台初始化任务：
///    a. initializeApp()（加载 baseUrl / Dio / DB / Controller）
///    b. GitHubReleaseService.checkForUpdate()（检查更新）
///    c. ApiServerSwitcher.fetchLatestDomain()（检查更新完成后获取最新域名：
///       显示"正在获取新域名"，成功提示成功及新域名，失败提示失败后继续）
///    d. 等待全部完成 + 显示至少 2 秒（避免加载太快闪屏）
/// 4. 全部完成：
///    - 有新版本 → 弹出 UpdateDialog
///      * release.forceUpdate = true（body 含 [强制更新] 标记）：
///        仅"立即更新"按钮，用户必须更新或退出 App
///      * release.forceUpdate = false：有"立即更新"和"稍后"两个按钮，
///        用户可选"稍后"进入 App
///    - 无新版本或检查失败 → 直接切换到 MainShell
///
/// **关键设计：用 [GlobalKey]<[NavigatorState]> 获取 Navigator context**
///
/// SplashPage 是 runApp 的根 widget，build 返回 MaterialApp（含 Navigator）。
/// 但 [_SplashPageState] 的 `context` 是 SplashPage widget 的 context，
/// 在 MaterialApp 之上，**不在 Navigator 树下**。
/// 直接调用 `showDialog(context: context, ...)` 会抛
/// "Navigator operation requested with a context that does not include a Navigator"。
///
/// 解决方案：给 MaterialApp 设置 `navigatorKey`，通过 `_navigatorKey.currentContext`
/// 获取 MaterialApp 内部 Navigator 的 context，用它调用 showDialog。
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
  /// MaterialApp 的 Navigator key
  ///
  /// 用于获取 MaterialApp 内部的 context（在 Navigator 树下），
  /// 让 showDialog 能正常工作（详见类文档说明）。
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// 是否已启动初始化序列（防止重复触发）
  bool _startupStarted = false;

  /// 当前加载阶段文案（动态更新）
  String _loadingText = '正在加载...';

  /// 初始化失败的错误信息（非空时展示重试按钮）
  ///
  /// 旧实现把 initializeApp 异常静默吞掉，用户看到的是「卡在 Splash」，
  /// 无法重试也无法获知原因。这里把错误展示出来并加重试按钮。
  String _initError = '';

  /// 域名获取结果状态（pending 期间显示常规加载指示）
  _DomainStatus _domainStatus = _DomainStatus.pending;

  /// 获取到的最新域名（[_domainStatus] 为 success 时非空）
  String? _fetchedDomain;

  /// 启动序列：initializeApp + checkForUpdate + 最小展示 2 秒
  ///
  /// [dialogContext] 是 MaterialApp 内部 Navigator 的 context，
  /// 用于调用 UpdateDialog.show（showDialog 需要 context 在 Navigator 树下）。
  Future<void> _runStartupSequence(BuildContext dialogContext) async {
    final stopwatch = Stopwatch()..start();

    // 阶段 1：初始化（数据 / 网络 / 主题）
    setState(() {
      _loadingText = '正在加载应用数据...';
      _initError = '';
    });
    try {
      await initializeApp();
    } catch (e, st) {
      // 初始化失败：展示错误 + 重试按钮，不再继续后续阶段
      appLogger.e('initializeApp failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _initError = e.toString());
      return;
    }

    // 阶段 2：检查更新
    setState(() => _loadingText = '正在检查更新...');
    GitHubRelease? update;
    try {
      update = await GitHubReleaseService.checkForUpdate();
    } catch (e, st) {
      // 更新检查失败不阻塞进入 App（用户离线时仍可使用）
      appLogger.w('checkForUpdate failed: $e', error: e, stackTrace: st);
    }

    // 阶段 3：获取最新域名（检查更新完成后）
    //
    // 通过根域名 http://68ck.net 解析最新源站地址并应用：
    // - 获取中：显示"正在获取新域名"
    // - 成功：提示成功及新域名（服务器管理只保留根域名与新域名）
    // - 失败：提示失败，随后正常进入 App（后续逻辑不变）
    setState(() => _loadingText = '正在获取新域名...');
    String? latestDomain;
    try {
      latestDomain = await ApiServerSwitcher.fetchLatestDomain();
    } catch (e, st) {
      // 获取失败不阻塞进入 App（使用已保存的域名继续）
      appLogger.e('fetchLatestDomain failed', error: e, stackTrace: st);
    }
    if (!mounted) return;
    setState(() {
      _fetchedDomain = latestDomain;
      _domainStatus =
          latestDomain != null ? _DomainStatus.success : _DomainStatus.failure;
    });
    // 结果停留展示，让用户看清成功 / 失败提示
    await Future.delayed(const Duration(seconds: 2));

    // 阶段 4：保证 splash 至少展示 2 秒（避免快速加载导致闪屏）
    const minSplashDuration = Duration(seconds: 2);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }

    // 阶段 5：进入下一步
    if (!mounted) return;

    if (update != null) {
      // 有新版本 → 显示更新对话框
      // - 强制更新（release.body 含 [强制更新] 标记）：仅"立即更新"按钮，
      //   关闭对话框意味着用户已退出 App 或正在安装新版本，不调用 _enterApp
      // - 非强制更新：用户可选"稍后"跳过本次更新，调用 _enterApp 进入 App
      setState(() {
        // 恢复常规加载视图以显示"发现新版本"（域名结果已停留展示完毕）
        _domainStatus = _DomainStatus.pending;
        _loadingText = '发现新版本';
      });
      // 用 MaterialApp 内部 Navigator 的 context 调用 showDialog
      // 不能用 _SplashPageState.context（它不在 Navigator 树下，showDialog 会抛错）
      if (!dialogContext.mounted) return;
      await UpdateDialog.show(
        dialogContext,
        release: update,
        forceUpdate: update.forceUpdate,
        onLater: update.forceUpdate ? null : _enterApp,
      );
      // 强制更新模式下对话框关闭后不进入旧版本 App（用户已退出或在安装新版本）；
      // 非强制模式下 onLater 已被调用进入 App。
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
      navigatorKey: _navigatorKey,
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
            child: Builder(
              builder: (innerContext) {
                // Builder 内部 context 在 MaterialApp 的 Navigator 树下，
                // 用它触发 _runStartupSequence（在第一帧渲染后）。
                // 用 _startupStarted 防止 rebuild 时重复触发。
                if (!_startupStarted) {
                  _startupStarted = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _runStartupSequence(innerContext);
                  });
                }
                return _buildSplashBody();
              },
            ),
          ),
        ),
      ),
    );
  }

  /// splash 主体内容（Logo / 名称 / 加载指示 / 版本号）
  ///
  /// 当 [_initError] 非空时切换为错误视图 + 重试按钮，
  /// 让用户能看到初始化失败原因并主动重试。
  Widget _buildSplashBody() {
    return SizedBox(
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
          // 状态指示器 / 错误视图
          if (_initError.isEmpty)
            _buildStatusIndicator()
          else
            _buildErrorIndicator(),
          const SizedBox(height: DesignTokens.spaceXl),
          // 版本号
          _buildVersion(),
          const SizedBox(height: DesignTokens.space2xl),
        ],
      ),
    );
  }

  /// 初始化失败视图（错误图标 + 错误信息 + 重试按钮）
  Widget _buildErrorIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            color: DesignTokens.colorDestructive,
            size: 40,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            '初始化失败',
            style: GoogleFonts.poppins(
              fontSize: DesignTokens.textBody,
              fontWeight: FontWeight.w600,
              color: _kOnBackgroundColor,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            _initError,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: DesignTokens.textCaption,
              color: _kOnBackgroundMutedColor,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          FilledButton.icon(
            onPressed: _retryInitialization,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 重试初始化：清空错误状态后重新触发启动序列
  void _retryInitialization() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    setState(() {
      _initError = '';
      _loadingText = '正在加载...';
      _domainStatus = _DomainStatus.pending;
      _fetchedDomain = null;
    });
    _runStartupSequence(ctx);
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
      tween: Tween(begin: 0.85, end: 1.0),
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
              ThemePreset.defaultPrimaryColor,
              ThemePreset.defaultSecondaryColor,
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

  /// 启动状态指示器：常规加载 / 域名获取结果
  ///
  /// 根据 [_domainStatus] 切换：
  /// - pending：CircularProgressIndicator + 当前阶段文案（含"正在获取新域名"）
  /// - success：成功图标 + "域名获取成功" + 获取到的新域名
  /// - failure：失败图标 + "域名获取失败" + 说明文案
  Widget _buildStatusIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_domainStatus) {
        _DomainStatus.success => _buildDomainSuccessView(),
        _DomainStatus.failure => _buildDomainFailureView(),
        _DomainStatus.pending => _buildLoadingIndicator(),
      },
    );
  }

  /// 域名获取成功视图（成功图标 + 获取到的新域名）
  Widget _buildDomainSuccessView() {
    return Column(
      key: const ValueKey('splash-domain-success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          PhosphorIconsFill.checkCircle,
          color: DesignTokens.colorSuccess,
          size: 36,
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        Text(
          '域名获取成功',
          style: GoogleFonts.poppins(
            fontSize: DesignTokens.textBody,
            fontWeight: FontWeight.w600,
            color: _kOnBackgroundColor,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          _fetchedDomain ?? '',
          style: GoogleFonts.poppins(
            fontSize: DesignTokens.textCaption,
            color: _kOnBackgroundMutedColor,
          ),
        ),
      ],
    );
  }

  /// 域名获取失败视图（失败图标 + 失败说明，随后正常进入 App）
  Widget _buildDomainFailureView() {
    return Column(
      key: const ValueKey('splash-domain-failure'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          PhosphorIconsFill.warningCircle,
          color: DesignTokens.colorDestructive,
          size: 36,
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        Text(
          '域名获取失败',
          style: GoogleFonts.poppins(
            fontSize: DesignTokens.textBody,
            fontWeight: FontWeight.w600,
            color: _kOnBackgroundColor,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          '将使用已保存的源站地址进入',
          style: GoogleFonts.poppins(
            fontSize: DesignTokens.textCaption,
            color: _kOnBackgroundMutedColor,
          ),
        ),
      ],
    );
  }

  /// 加载指示器
  ///
  /// 主题色 CircularProgressIndicator + 动态加载文案
  Widget _buildLoadingIndicator() {
    return Column(
      key: const ValueKey('splash-loading'),
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
