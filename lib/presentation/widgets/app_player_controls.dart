import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';
import 'package:yellow_depot/core/theme/theme_presets.dart';

/// 自定义播放器控制层（作为 ChewieController.customControls 使用）
///
/// 替换 chewie 默认 MaterialControls，统一内联 / 全屏的手势与控制栏：
/// - 单击画面：显示 / 隐藏控制栏（播放中 3 秒无操作自动隐藏，暂停时保持）
/// - 双击画面：播放 / 暂停
/// - 水平拖动：快进 / 快退（满屏宽约 90 秒，实时目标时间浮层，松手跳转）
/// - 控制栏：播放/暂停、进度条（可拖动）、时间、倍速循环、全屏切换
///
/// 相比 chewie 默认控件的改进：
/// - 手势层 opaque 全量接管：拖动 seek 时不再误触发控制栏显示
/// - 控制栏仅底部渐变条，不再整屏变暗
/// - chewie 全屏 route 同样使用 customControls，手势在全屏也生效
class AppPlayerControls extends StatefulWidget {
  const AppPlayerControls({super.key});

  @override
  State<AppPlayerControls> createState() => _AppPlayerControlsState();
}

class _AppPlayerControlsState extends State<AppPlayerControls> {
  ChewieController? _chewie;

  VideoPlayerController get _vpc => _chewie!.videoPlayerController;

  /// 控制栏可见性（初始隐藏，暂停态自动显示见 [_scheduleHide]）
  bool _controlsVisible = false;

  /// 控制栏自动隐藏计时器（播放中 3 秒无操作隐藏）
  Timer? _hideTimer;

  /// 水平拖动 seek：拖动开始时的播放位置（秒）
  double? _dragStartSeconds;

  /// 水平拖动 seek：累计水平位移（px，右正左负）
  double _accumulatedDx = 0;

  /// 当前 seek 目标位置（非 null 时显示浮层）
  Duration? _seekTarget;

  /// 手势层宽度（位移 → 时间换算基准），build 时由 LayoutBuilder 更新
  double _gestureWidth = 1;

  /// 倍速循环序列（点击倍速按钮按序切换）
  static const List<double> _speeds = [1.0, 1.25, 1.5, 2.0, 3.0];

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // 控制栏显隐
  // ============================================================

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  /// 播放中 3 秒无操作自动隐藏控制栏；暂停时保持可见
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final v = _vpc.value;
      if (v.isInitialized && v.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  // ============================================================
  // 播放控制
  // ============================================================

  void _togglePlayPause() {
    final v = _vpc.value;
    if (!v.isInitialized) return;
    if (v.isPlaying) {
      _vpc.pause();
      // 暂停时保持控制栏可见，便于继续播放
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      _vpc.play();
      _scheduleHide();
    }
  }

  void _cycleSpeed() {
    final cur = _vpc.value.playbackSpeed;
    var idx = _speeds.indexWhere((s) => (s - cur).abs() < 0.01);
    if (idx < 0) idx = -1;
    final next = _speeds[(idx + 1) % _speeds.length];
    _vpc.setPlaybackSpeed(next);
    _scheduleHide();
  }

  void _toggleFullScreen() {
    final chewie = _chewie;
    if (chewie == null) return;
    if (chewie.isFullScreen) {
      chewie.exitFullScreen();
    } else {
      chewie.enterFullScreen();
    }
    _scheduleHide();
  }

  // ============================================================
  // 手势：水平拖动快进 / 快退
  // ============================================================

  void _onHorizontalDragStart(DragStartDetails details) {
    final v = _vpc.value;
    if (!v.isInitialized) return;
    _dragStartSeconds = v.position.inMilliseconds / 1000;
    _accumulatedDx = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragStartSeconds == null) return;
    final v = _vpc.value;
    if (!v.isInitialized) return;
    _accumulatedDx += details.delta.dx;
    // 满屏宽度 ≈ 90 秒（与主流播放器手感一致）
    final secondsPerPx = 90 / _gestureWidth;
    final durationSec = v.duration.inMilliseconds / 1000;
    final target = (_dragStartSeconds! + _accumulatedDx * secondsPerPx)
        .clamp(0.0, durationSec);
    setState(() {
      _seekTarget = Duration(milliseconds: (target * 1000).round());
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    final target = _seekTarget;
    _dragStartSeconds = null;
    if (target == null) return;
    final v = _vpc.value;
    if (v.isInitialized) {
      final clamped = target > v.duration ? v.duration : target;
      await _vpc.seekTo(clamped < Duration.zero ? Duration.zero : clamped);
    }
    if (!mounted) return;
    // 保留浮层 600ms 展示跳转结果，再隐藏
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekTarget = null);
    });
  }

  void _onHorizontalDragCancel() {
    _dragStartSeconds = null;
    if (mounted) setState(() => _seekTarget = null);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    _chewie = ChewieController.of(context);
    final colors = AppTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _gestureWidth = constraints.maxWidth;
        // 任何按下 / 移动都重置自动隐藏（进度条拖动中控制栏不会消失）
        return Listener(
          onPointerDown: (_) {
            if (_controlsVisible) _scheduleHide();
          },
          onPointerMove: (_) {
            if (_controlsVisible) _scheduleHide();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _togglePlayPause,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 控制栏（底部渐变条，不整屏变暗）
                _buildControlsBar(colors),
                // 拖动中的目标时间浮层
                if (_seekTarget != null)
                  Center(child: _buildSeekOverlay()),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 底部控制栏：播放/暂停 + 时间 + 进度条 + 倍速 + 全屏
  Widget _buildControlsBar(ThemeColors colors) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0, 1],
              ),
            ),
            padding: const EdgeInsets.only(
              left: DesignTokens.spaceSm,
              right: DesignTokens.spaceSm,
              bottom: DesignTokens.spaceSm,
            ),
            child: AnimatedBuilder(
              animation: _vpc,
              builder: (context, _) {
                final v = _vpc.value;
                return Row(
                  children: [
                    _buildPlayPauseButton(v.isPlaying),
                    const SizedBox(width: DesignTokens.spaceXs),
                    Text(
                      '${_formatDuration(v.position)} / '
                      '${_formatDuration(v.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.textLabel,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _vpc,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: DesignTokens.spaceSm,
                        ),
                        colors: VideoProgressColors(
                          playedColor: colors.primary,
                          backgroundColor: Colors.white24,
                          bufferedColor: Colors.white38,
                        ),
                      ),
                    ),
                    _buildSpeedButton(v.playbackSpeed),
                    _buildFullScreenButton(_chewie?.isFullScreen ?? false),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(bool isPlaying) {
    return IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      color: Colors.white,
      iconSize: 26,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(4),
      onPressed: _togglePlayPause,
      tooltip: isPlaying ? '暂停' : '播放',
    );
  }

  /// 倍速按钮（点击按 [_speeds] 循环切换）
  Widget _buildSpeedButton(double speed) {
    final label = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return TextButton(
      onPressed: _cycleSpeed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: const TextStyle(
          fontSize: DesignTokens.textLabel,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text('${label}x'),
    );
  }

  Widget _buildFullScreenButton(bool isFullScreen) {
    return IconButton(
      icon: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
      color: Colors.white,
      iconSize: 26,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(4),
      onPressed: _toggleFullScreen,
      tooltip: isFullScreen ? '退出全屏' : '全屏',
    );
  }

  /// 拖动 seek 的目标时间浮层（快进 / 快退图标 + 目标时间）
  Widget _buildSeekOverlay() {
    final target = _seekTarget!;
    final v = _vpc.value;
    // 拖动中与起点比方向；松手后（600ms 内）与当前位置比
    final referenceSec = _dragStartSeconds ??
        v.position.inMilliseconds / 1000;
    final isForward = target.inMilliseconds / 1000 >= referenceSec;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLg,
        vertical: DesignTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForward ? Icons.fast_forward : Icons.fast_rewind,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Text(
            _formatDuration(target),
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textH2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 时长格式化（m:ss / h:mm:ss）
  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}
