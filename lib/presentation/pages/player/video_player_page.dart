import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:videohub/core/theme/app_theme.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/presentation/controllers/video_player_controller.dart';

/// 视频播放器页面
///
/// 严格遵循需求：
/// - 支持全屏 / 竖屏切换、屏幕常亮（播放中）
/// - 手势调节亮度、音量、播放进度
/// - 自动适配视频比例、自适应屏幕尺寸
/// - 暂停、播放、快进、快退、倍速播放（0.5x-2.0x）
/// - 进度条拖拽、缓冲进度展示
/// - 网络卡顿缓冲加载动画、播放失败重试按钮
/// - 空地址、解析失败、网络异常兜底 UI
class VideoPlayerPage extends GetView<PlayerPageController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 视频播放页是 MASTER.md §7 唯一允许的黑底
      body: SafeArea(
        child: Obx(() => _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (controller.state.value) {
      case PlayerState.idle:
      case PlayerState.decrypting:
        return _DecryptingView(countdown: controller.countdown.value);
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
        return _ErrorView(
          message: controller.errorMessage.value,
          onRetry: controller.retry,
        );
    }
  }
}

/// 解密中视图（6 秒倒计时）
class _DecryptingView extends StatelessWidget {
  final int countdown;
  const _DecryptingView({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: countdown == 0 ? null : countdown / 6,
                  color: colors.primary,
                  strokeWidth: 4,
                ),
              ),
              Text(
                '$countdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            '正在解析播放地址',
            style: TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            '模拟移动端点击行为，请稍候...',
            style: TextStyle(
              color: Colors.white70,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 播放中视图（集成 Chewie）
class _PlayingView extends StatelessWidget {
  final PlayerPageController controller;
  final bool showBufferingIndicator;

  const _PlayingView({
    required this.controller,
    this.showBufferingIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final videoController = controller.videoController;
    if (videoController == null || !videoController.value.isInitialized) {
      return const _LoadingView(message: '初始化播放器...');
    }

    final colors = AppTheme.colorsOf(context);

    // 构造 Chewie 控件（每次重建保证主题色生效）
    final chewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      showControlsOnInitialize: true,
      customControls: _VideoHubControls(
        controller: controller,
        themeColor: colors.primary,
      ),
      placeholder: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: showBufferingIndicator
            ? CircularProgressIndicator(color: colors.primary)
            : null,
      ),
      errorBuilder: (context, errorMessage) {
        return _ErrorView(
          message: errorMessage,
          onRetry: controller.retry,
        );
      },
    );

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: videoController.value.aspectRatio,
            child: Chewie(controller: chewieController),
          ),
        ),
        // 手势叠加层
        Positioned.fill(
          child: _GestureOverlay(controller: controller),
        ),
      ],
    );
  }
}

/// 手势叠加层（亮度 / 音量 / 进度调节）
class _GestureOverlay extends StatelessWidget {
  final PlayerPageController controller;
  const _GestureOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: controller.togglePlayPause,
      onHorizontalDragUpdate: (details) {
        // 横向拖动：进度调节
        final dx = details.delta.dx;
        final positionMs = controller.positionMs.value;
        final durationMs = controller.durationMs.value;
        if (durationMs == 0) return;
        final deltaMs = (dx * durationMs / 300).toInt();
        final target = (positionMs + deltaMs).clamp(0, durationMs);
        controller.seekTo(Duration(milliseconds: target));
      },
      onVerticalDragUpdate: (details) {
        final dx = details.delta.dx;
        // 左半屏：亮度；右半屏：音量
        final isLeft =
            details.globalPosition.dx < MediaQuery.of(context).size.width / 2;
        if (isLeft) {
          controller.setBrightness(
            controller.brightness.value - details.delta.dy / 500,
          );
        } else {
          controller.setVolume(
            controller.volume.value - details.delta.dy / 500,
          );
        }
      },
      child: const SizedBox.shrink(),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.clockClockwise(),
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

/// 错误视图（带重试按钮）
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle(),
              color: colors.destructive,
              size: 56,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: DesignTokens.textCaption,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义 Chewie 控件皮肤（适配 APP 主题色）
class _VideoHubControls extends StatelessWidget {
  final PlayerPageController controller;
  final Color themeColor;

  const _VideoHubControls({
    required this.controller,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final position = controller.positionMs.value;
      final duration = controller.durationMs.value;
      final buffered = controller.bufferedMs.value;
      final isPlaying = controller.state.value == PlayerState.playing;

      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
              Colors.transparent,
              Colors.black54,
            ],
            stops: [0, 0.2, 0.8, 1],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 顶部栏
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: Get.back,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
            // 中央播放/暂停按钮
            Center(
              child: IconButton(
                iconSize: 48,
                color: Colors.white,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: controller.togglePlayPause,
              ),
            ),
            // 底部进度条 + 时间
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceLg,
                vertical: DesignTokens.spaceSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 自定义进度条（带缓冲指示）
                  _ProgressIndicator(
                    position: position,
                    duration: duration,
                    buffered: buffered,
                    color: themeColor,
                    onSeek: (ms) =>
                        controller.seekTo(Duration(milliseconds: ms)),
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.textCaption,
                        ),
                      ),
                      const Spacer(),
                      // 倍速按钮
                      PopupMenuButton<double>(
                        color: Colors.black87,
                        child: Text(
                          '${controller.playbackSpeed.value}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.textCaption,
                          ),
                        ),
                        onSelected: controller.setPlaybackSpeed,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 0.5, child: Text('0.5x')),
                          PopupMenuItem(value: 0.75, child: Text('0.75x')),
                          PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          controller.isFullscreen.value
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: controller.toggleFullscreen,
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.textCaption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

/// 自定义进度条（含缓冲指示）
class _ProgressIndicator extends StatelessWidget {
  final int position;
  final int duration;
  final int buffered;
  final Color color;
  final ValueChanged<int> onSeek;

  const _ProgressIndicator({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.color,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final durationSafe = duration == 0 ? 1 : duration;
    final positionRatio = (position / durationSafe).clamp(0.0, 1.0);
    final bufferedRatio = (buffered / durationSafe).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final ratio = details.localPosition.dx / width;
            onSeek((ratio * durationSafe).toInt());
          },
          onHorizontalDragUpdate: (details) {
            final ratio = details.localPosition.dx / width;
            onSeek((ratio * durationSafe).toInt().clamp(0, duration));
          },
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 背景轨道
                Container(
                  height: 3,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 缓冲轨道
                Container(
                  height: 3,
                  width: width * bufferedRatio,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 当前进度
                Container(
                  height: 3,
                  width: width * positionRatio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Thumb
                Positioned(
                  left: (width * positionRatio - 7).clamp(0, width - 14),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
