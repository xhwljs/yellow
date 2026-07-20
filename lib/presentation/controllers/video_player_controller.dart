import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:yellow_depot/core/error/exceptions.dart';
import 'package:yellow_depot/core/player/url_decryptor.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/video_detail.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 播放器状态
enum PlayerState {
  idle,
  decrypting,
  loading,
  ready,
  playing,
  paused,
  buffering,
  error,
  urlExpired,
}

/// 播放器配置参数
class PlayerArgs {
  final String videoId;
  final String title;
  final String coverUrl;
  final int categoryId;
  final int initialPositionMs;
  final int? durationMs;
  final VideoDetail? existingDetail;

  const PlayerArgs({
    required this.videoId,
    required this.title,
    required this.coverUrl,
    required this.categoryId,
    this.initialPositionMs = 0,
    this.durationMs,
    this.existingDetail,
  });
}

/// 视频播放器页面控制器（GetxController）
///
/// 严格遵循需求：
/// - 视频地址失效自动重载解密地址重试播放
/// - 网络卡顿缓冲加载动画、播放失败重试按钮
/// - 页面退出自动暂停释放播放器资源
/// - 记录视频播放进度，再次进入自动续播
/// - 适配解密后动态视频 URL 实时加载
///
/// **生命周期**：实现 [WidgetsBindingObserver]，App 切到后台时自动暂停播放，
/// 切回前台时按需恢复。避免后台继续播放音频被系统判定为异常占用资源。
class PlayerPageController extends GetxController
    with WidgetsBindingObserver {
  PlayerPageController({
    required this.args,
    required this.decryptor,
    required this.historyRepo,
  });

  final PlayerArgs args;
  final UrlDecryptor decryptor;
  final HistoryRepository historyRepo;
  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;
  final VolumeController _volumeController = VolumeController.instance;

  // 状态
  final Rx<PlayerState> state = PlayerState.idle.obs;
  final RxString errorMessage = ''.obs;
  final RxDouble brightness = 0.5.obs;
  final RxDouble volume = 0.5.obs;
  final RxDouble playbackSpeed = 1.0.obs;
  final RxBool isFullscreen = false.obs;
  final RxInt positionMs = 0.obs;
  final RxInt durationMs = 0.obs;
  final RxInt bufferedMs = 0.obs;

  // 播放器实例
  vp.VideoPlayerController? _videoController;
  vp.VideoPlayerController? get videoController => _videoController;

  VideoDetail? _detail;
  VideoDetail? get detail => _detail;

  String? _currentPlayUrl;
  String? get currentPlayUrl => _currentPlayUrl;

  double _originalBrightness = 0.5;
  double _originalVolume = 0.5;
  DateTime? _lastHistorySave;

  /// App 切后台前是否正在播放（用于切回前台时恢复）
  bool _wasPlayingBeforePause = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // 进入播放页立即开启屏幕常亮 — 即使解析阶段（decrypting）耗时数秒
    // 也保持屏幕常亮，避免锁屏中断播放初始化流程。
    // wakelock_plus 使用 FLAG_KEEP_SCREEN_ON（WindowManager flag），
    // 不是 PowerManager WakeLock，无需 WAKE_LOCK 权限。
    WakelockPlus.enable().catchError((_) {});
    _initializeAndPlay();
  }

  @override
  void onClose() {
    _disposeResources();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App 切后台/失焦 → 暂停播放，记录原状态用于恢复
        _wasPlayingBeforePause = vc.value.isPlaying;
        if (_wasPlayingBeforePause) {
          vc.pause();
        }
        // 关闭屏幕常亮，避免后台未暂停时浪费电
        try {
          WakelockPlus.disable();
        } catch (_) {}
        break;
      case AppLifecycleState.resumed:
        // 切回前台 → 若之前在播放则恢复
        if (_wasPlayingBeforePause) {
          vc.play();
          _wasPlayingBeforePause = false;
          // 恢复屏幕常亮
          try {
            WakelockPlus.enable();
          } catch (_) {}
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializeAndPlay() async {
    state.value = PlayerState.decrypting;
    try {
      // 1. 解密获取播放地址
      final result = await decryptor.decryptPlayUrl(
        args.videoId,
        existingDetail: args.existingDetail,
      );
      _detail = result.detail;
      _currentPlayUrl = result.playUrl;

      // 2. 记录原始亮度/音量
      // （屏幕常亮已在 onInit 中开启，此处无需重复调用）
      try {
        // screen_brightness 1.0.1 API：current getter（2.x 改名为 application）
        _originalBrightness = await _screenBrightness.current;
        brightness.value = _originalBrightness;
      } catch (_) {}
      try {
        _originalVolume = await _volumeController.getVolume();
        volume.value = _originalVolume;
      } catch (_) {}

      // 3. 初始化 video_player
      state.value = PlayerState.loading;
      _videoController = vp.VideoPlayerController.networkUrl(
        Uri.parse(_currentPlayUrl!),
        videoPlayerOptions: vp.VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoController!.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw const TimeoutException('视频初始化超时'),
          );

      // 4. 续播
      if (args.initialPositionMs > 0) {
        await _videoController!.seekTo(
          Duration(milliseconds: args.initialPositionMs),
        );
      }

      // 5. 设置初始时长
      durationMs.value = _videoController!.value.duration.inMilliseconds;

      // 6. 监听播放器状态
      _videoController!.addListener(_onVideoUpdate);

      // 7. 设置倍速
      await _videoController!.setPlaybackSpeed(playbackSpeed.value);

      // 8. 自动播放
      await _videoController!.play();
      state.value = PlayerState.playing;
    } on UrlExpiredException {
      state.value = PlayerState.urlExpired;
      errorMessage.value = '播放地址已过期，正在重新获取';
      await _retryWithNewUrl();
    } on DecryptException catch (e) {
      state.value = PlayerState.error;
      errorMessage.value = e.message;
    } catch (e) {
      state.value = PlayerState.error;
      errorMessage.value = '视频加载失败：$e';
      appLogger.e('播放器初始化失败', error: e);
    }
  }

  /// video_player 状态变更监听
  void _onVideoUpdate() {
    if (_videoController == null) return;
    final value = _videoController!.value;

    positionMs.value = value.position.inMilliseconds;
    durationMs.value = value.duration.inMilliseconds;
    bufferedMs.value = value.buffered.last.end.inMilliseconds;

    if (value.isBuffering) {
      if (state.value != PlayerState.buffering) {
        state.value = PlayerState.buffering;
      }
    } else if (value.isPlaying) {
      if (state.value != PlayerState.playing) {
        state.value = PlayerState.playing;
      }
      _throttledUpdateHistory();
    } else if (!value.isInitialized) {
      // ignore
    } else if (!value.isPlaying &&
        state.value != PlayerState.paused &&
        !value.isCompleted) {
      state.value = PlayerState.paused;
    }

    if (value.hasError) {
      state.value = PlayerState.error;
      errorMessage.value = '播放错误：${value.errorDescription ?? '未知错误'}';
    }
  }

  /// 节流更新播放历史（5 秒一次）
  void _throttledUpdateHistory() {
    final now = DateTime.now();
    if (_lastHistorySave != null &&
        now.difference(_lastHistorySave!) < const Duration(seconds: 5)) {
      return;
    }
    _lastHistorySave = now;
    _saveHistory();
  }

  /// 保存播放进度
  Future<void> _saveHistory() async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    try {
      await historyRepo.upsertHistory(
        videoId: args.videoId,
        title: args.title,
        coverUrl: args.coverUrl,
        categoryId: args.categoryId,
        positionMs: _videoController!.value.position.inMilliseconds,
        durationMs: _videoController!.value.duration.inMilliseconds,
      );
    } catch (e) {
      appLogger.w('保存播放历史失败: $e');
    }
  }

  /// 地址失效时重新拉取
  Future<void> _retryWithNewUrl() async {
    try {
      final newUrl = await decryptor.refreshPlayUrl(args.videoId);
      _currentPlayUrl = newUrl;
      await _videoController?.dispose();
      _videoController = vp.VideoPlayerController.networkUrl(Uri.parse(newUrl));
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoUpdate);
      await _videoController!.play();
      state.value = PlayerState.playing;
      errorMessage.value = '';
    } catch (e) {
      state.value = PlayerState.error;
      errorMessage.value = '重新获取播放地址失败：$e';
    }
  }

  /// 用户点击重试
  Future<void> retry() async {
    await _disposeResources();
    await _initializeAndPlay();
  }

  /// 播放/暂停
  Future<void> togglePlayPause() async {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      await _videoController!.pause();
      state.value = PlayerState.paused;
    } else {
      await _videoController!.play();
      state.value = PlayerState.playing;
    }
  }

  /// 快进/快退
  Future<void> seek(Duration offset) async {
    if (_videoController == null) return;
    final current = _videoController!.value.position;
    final target = current + offset;
    await _videoController!.seekTo(target);
  }

  /// 拖拽到指定位置
  Future<void> seekTo(Duration position) async {
    if (_videoController == null) return;
    await _videoController!.seekTo(position);
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(double speed) async {
    if (_videoController == null) return;
    await _videoController!.setPlaybackSpeed(speed);
    playbackSpeed.value = speed;
  }

  /// 切换全屏
  void toggleFullscreen() {
    isFullscreen.value = !isFullscreen.value;
  }

  /// 设置亮度（0-1）
  Future<void> setBrightness(double value) async {
    brightness.value = value.clamp(0.0, 1.0);
    try {
      // screen_brightness 1.0.1 API：setScreenBrightness（2.x 改名为 setApplicationScreenBrightness）
      await _screenBrightness.setScreenBrightness(brightness.value);
    } catch (_) {}
  }

  /// 设置音量（0-1）
  Future<void> setVolume(double value) async {
    volume.value = value.clamp(0.0, 1.0);
    try {
      await _volumeController.setVolume(volume.value);
    } catch (_) {}
  }

  /// 释放资源
  Future<void> _disposeResources() async {
    try {
      await _saveHistory();
    } catch (_) {}
    try {
      _videoController?.removeListener(_onVideoUpdate);
      await _videoController?.pause();
      await _videoController?.dispose();
    } catch (_) {}
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      // screen_brightness 1.0.1 API：resetScreenBrightness（2.x 改名为 resetApplicationScreenBrightness）
      await _screenBrightness.resetScreenBrightness();
    } catch (_) {}
    try {
      await _volumeController.setVolume(_originalVolume);
    } catch (_) {}
    _videoController = null;
    _currentPlayUrl = null;
  }
}
