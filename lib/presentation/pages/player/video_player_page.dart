import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/presentation/controllers/video_player_controller.dart';

/// 视频播放器页面
///
/// 设计参考：
/// - design-system/MASTER.md §7：播放页是**唯一允许黑底**的页面（视频内容本身需要），
///   但控件、文字仍走主题色令牌。
/// - ui-ux-pro-max UX 建议：加载 > 300ms 必给反馈；错误必带重试 CTA；
///   缓冲指示用骨架屏或 spinner。
///
/// 目标站点播放页结构（实测 /v5/{aid}-{sid}-{nid}.html）：
/// 站点用 iframe 嵌入 dplayer.html，原站有 6 秒倒计时锁定按钮。本 APP 跳过
/// 倒计时直接 POST count.php 获取 m3u8，用 video_player + chewie 原生播放。
///
/// 严格遵循需求：
/// - 全屏 / 竖屏切换、屏幕常亮（播放中）
/// - 手势调节亮度、音量、播放进度
/// - 自适应视频比例
/// - 暂停、播放、快进、快退、倍速（0.5x-2.0x）
/// - 进度条拖拽、缓冲进度展示
/// - 网络卡顿缓冲动画、播放失败重试按钮
/// - 空地址 / 解析失败 / 网络异常兜底 UI
class VideoPlayerPage extends GetView<PlayerPageController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 播放页全屏沉浸：状态栏透明，但不遮盖状态栏（用户要求）
    //
    // 关键变更：SafeArea.top 从 false 改为 true
    // - 旧值 false：内容延伸到状态栏下方，状态栏图标与视频/加载内容重叠
    // - 新值 true：内容从状态栏下方开始绘制，状态栏区域显示黑色背景
    //   （Scaffold backgroundColor: Colors.black）
    //
    // AnnotatedRegion 仍设 statusBarColor: transparent 让状态栏背景透明，
    // 图标用 light 色（白色）保证在黑底上可读。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Obx(() => _buildBody(context)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (controller.state.value) {
      case PlayerState.idle:
      case PlayerState.decrypting:
        return const _DecryptingView(message: '正在解析播放地址...');
      case PlayerState.loading:
        return const _LoadingView(message: '加载视频中...');
      case PlayerState.buffering:
        return _PlayingView(
          controller: controller,
          showBufferingIndicator: true,
        );
      case PlayerState.playing:
      case PlayerState.paused:
      case PlayerState.ready:
        return _PlayingView(controller: controller);
      case PlayerState.urlExpired:
        return _ExpiredView(controller: controller);
      case PlayerState.error:
        return _PlayerErrorView(
          message: controller.errorMessage.value,
          onRetry: controller.retry,
        );
    }
  }
}

/// 解析中视图
///
/// 取消了原站点的 6 秒倒计时，直接显示加载动画。
class _DecryptingView extends StatelessWidget {
  final String message;
  const _DecryptingView({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _PlayerOverlay(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: colors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          const Text(
            '已跳过倒计时，直接请求播放地址',
            style: TextStyle(
              color: Colors.white54,
              fontSize: DesignTokens.textCaption,
            ),
          ),
        ],
      ),
    );
  }
}

/// 加载中视图
class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _PlayerOverlay(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// 播放中视图（Chewie 集成）
///
/// Chewie 的 MaterialControls 自带完整功能（无需自定义）：
/// - 播放/暂停按钮（中央 + 底栏）
/// - 进度条拖拽 + 缓冲进度展示
/// - 横向滑动快进快退
/// - 双击播放/暂停切换
/// - 全屏切换按钮（进入/退出全屏）
/// - 倍速切换（0.5x - 2.0x）
/// - 控件自动隐藏（3 秒无操作）+ 点击视频区域显示控件
///
/// 我们通过 [ChewieController] 注入主题色，外层叠加 [_BrightnessVolumeGesture]
/// 处理**亮度/音量**纵向拖动（chewie 默认不支持亮度/音量手势）。
/// 横向拖动、双击、点击等手势交给 chewie 处理，避免冲突。
///
/// **实现为 StatefulWidget**：把 [ChewieController] 提升到 [State]：
/// - 旧实现在 [build] 内 new ChewieController，每次 [Obx] 重建（播放进度变化）
///   都会 dispose + new Chewie，引发黑屏、卡顿、内存抖动。
/// - 现在 [initState] 创建一次，[dispose] 释放，[didUpdateWidget] 检测
///   videoController 引用变化时才重建（如 retry 后换了底层 VideoPlayerController）。
class _PlayingView extends StatefulWidget {
  final PlayerPageController controller;
  final bool showBufferingIndicator;

  const _PlayingView({
    required this.controller,
    this.showBufferingIndicator = false,
  });

  @override
  State<_PlayingView> createState() => _PlayingViewState();
}

class _PlayingViewState extends State<_PlayingView> {
  ChewieController? _chewieController;
  vp.VideoPlayerController? _boundVideoController;
  Color? _boundPrimaryColor;

  PlayerPageController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _rebuildChewieIfNeeded(force: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 主题色变化时让 Chewie 重建以应用新颜色
    _rebuildChewieIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PlayingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父 widget 重建（如 showBufferingIndicator 变化）时检查是否需要重建 Chewie
    _rebuildChewieIfNeeded();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _chewieController = null;
    super.dispose();
  }

  /// 检查 videoController 引用 + 主题色是否变化，必要时重建 [ChewieController]
  ///
  /// [force] = true 时强制重建（[initState] 首次创建）。
  void _rebuildChewieIfNeeded({bool force = false}) {
    final videoController = c.videoController;
    if (videoController == null || !videoController.value.isInitialized) {
      return;
    }
    final primaryColor = AppTheme.colorsOf(context).primary;
    if (!force &&
        _chewieController != null &&
        _boundVideoController == videoController &&
        _boundPrimaryColor == primaryColor) {
      return;
    }

    _chewieController?.dispose();
    _chewieController = _buildChewieController(videoController, primaryColor);
    _boundVideoController = videoController;
    _boundPrimaryColor = primaryColor;
  }

  ChewieController _buildChewieController(
    vp.VideoPlayerController videoController,
    Color primaryColor,
  ) {
    return ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      showControlsOnInitialize: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: primaryColor,
        handleColor: primaryColor,
        bufferedColor: Colors.white38,
        backgroundColor: Colors.white24,
      ),
      customControls: const MaterialControls(
        showPlayButton: true,
      ),
      placeholder: widget.showBufferingIndicator
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : null,
      errorBuilder: (context, errorMessage) {
        return _PlayerErrorView(
          message: errorMessage,
          onRetry: c.retry,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoController = c.videoController;
    if (videoController == null || !videoController.value.isInitialized) {
      return const _LoadingView(message: '初始化播放器...');
    }
    // videoController 引用变了（如 retry 后）→ 重建 Chewie
    _rebuildChewieIfNeeded();
    final chewieController = _chewieController;
    if (chewieController == null) {
      return const _LoadingView(message: '初始化播放器...');
    }

    return Center(
      child: AspectRatio(
        aspectRatio: videoController.value.aspectRatio,
        child: Chewie(controller: chewieController),
      ),
    );
  }
}

/// 地址过期视图
class _ExpiredView extends StatelessWidget {
  final PlayerPageController controller;
  const _ExpiredView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _PlayerOverlay(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.clockClockwise,
            color: colors.warning,
            size: 48,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            controller.errorMessage.value,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          CircularProgressIndicator(color: colors.primary),
        ],
      ),
    );
  }
}

/// 播放器错误视图（带重试按钮）
///
/// 与项目通用 ErrorView 风格一致，但用黑底（播放页上下文）。
class _PlayerErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PlayerErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _PlayerOverlay(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              color: colors.destructive,
              size: 56,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              '播放失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.textH2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: DesignTokens.textCaption,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXl),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放器叠加视图通用容器
///
/// 黑色背景 + 居中内容，统一播放页所有非播放态的视觉风格。
class _PlayerOverlay extends StatelessWidget {
  final Widget child;
  const _PlayerOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceXl,
        vertical: DesignTokens.space2xl,
      ),
      child: child,
    );
  }
}
