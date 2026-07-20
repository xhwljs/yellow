import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:yellow_depot/core/error/exceptions.dart';
import 'package:yellow_depot/core/player/url_decryptor.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/models/video.dart';
import 'package:yellow_depot/data/models/video_detail.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';
import 'package:yellow_depot/presentation/controllers/history_controller.dart';

/// 视频详情控制器
///
/// 包含播放入口：
/// **顶部内联播放器**（[inlineVideoController]/[inlineChewieController]）：
/// 在详情页 SliverAppBar 区域直接播放，使用 chewie 自带控件
/// （播放/暂停/进度/全屏/倍速/横向滑动快进/双击暂停/控件自动隐藏）。
///
/// 全屏播放使用 chewie 内联播放器自带的全屏按钮（点击切换横屏全屏），
/// 不再需要 FAB 跳转到独立的播放页。
///
/// **生命周期**：实现 [WidgetsBindingObserver]，App 切到后台时自动暂停播放，
/// 切回前台时按需恢复。避免后台继续播放音频被系统判定为异常占用资源。
///
/// **历史记录节流**：[_historySaveInterval] 控制 DB 写入节奏（5s 一次），
/// HistoryController 的 RxList 刷新做 2s 节流，避免每秒重建 History Tab。
class VideoDetailController extends GetxController
    with WidgetsBindingObserver {
  final VideoRepository _videoRepo;
  final FavoriteRepository _favoriteRepo;
  final HistoryRepository _historyRepo;
  final UrlDecryptor _decryptor;

  VideoDetailController(
    this._videoRepo,
    this._favoriteRepo,
    this._historyRepo,
    this._decryptor, {
    required this.videoId,
    this.initialCoverUrl = '',
    this.initialTitle = '',
  });

  final String videoId;

  /// 列表页传入的封面（详情页无独立封面时用此）
  final String initialCoverUrl;

  /// 列表页传入的标题（加载中显示）
  final String initialTitle;

  final Rx<VideoDetail?> detail = Rx<VideoDetail?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isFavorited = false.obs;
  final RxInt initialPositionMs = 0.obs;

  // ===== 内联播放器状态 =====
  //
  // 状态机：
  //   idle  ──[用户点击播放]──>  loading  ──[成功]──>  ready
  //                                   └──[失败]──>  error
  //   error ──[用户点击重试]──>  loading
  final Rx<vp.VideoPlayerController?> inlineVideoController =
      Rx<vp.VideoPlayerController?>(null);
  final Rx<ChewieController?> inlineChewieController =
      Rx<ChewieController?>(null);
  final RxBool inlineLoading = false.obs;
  final RxString inlineErrorMessage = ''.obs;
  bool _inlineStarted = false;

  // 历史记录实时保存
  //
  // 每 5 秒读取 video_player 当前 position/duration 写入数据库，
  // 并同步刷新 HistoryController 的 RxList，让 History Tab 实时更新。
  // 退出详情页（onClose）时也会保存最后一次进度。
  //
  // 旧实现是 1 秒一次，长时间播放会带来 DB 写放大 + RxList 全量重建。
  // 现在改为 5 秒一次（与文档对齐），HistoryController 刷新也做 2s 节流，
  // 让 UI 仍有「实时更新」体验但不会卡顿。
  Timer? _historySaveTimer;
  static const Duration _historySaveInterval = Duration(seconds: 5);

  /// HistoryController 刷新节流定时器
  ///
  /// 每次 [_saveHistoryFromPlayer] 完成后调 [_refreshHistoryController]，
  /// 但全量 loadHistory() 触发 RxList 重建会引发 History Tab UI 重建。
  /// 这里用 2 秒节流：5s 保存周期内最多刷新一次 UI。
  Timer? _historyRefreshThrottle;

  /// App 切后台前是否正在播放（用于切回前台时恢复）
  bool _wasPlayingBeforePause = false;

  /// 当前生效的封面 URL
  ///
  /// 详情页 parser 不提取封面（站点无独立大图），
  /// 优先使用列表页传入的 [initialCoverUrl]。
  String get effectiveCoverUrl {
    final d = detail.value;
    if (d != null && d.video.coverUrl.isNotEmpty) return d.video.coverUrl;
    return initialCoverUrl;
  }

  /// 当前生效的标题
  String get effectiveTitle {
    final d = detail.value;
    if (d != null && d.video.title.isNotEmpty) return d.video.title;
    return initialTitle;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    loadDetail();
  }

  @override
  void onClose() {
    // 退出详情页前最后一次保存播放进度，确保续播位置准确
    _saveHistoryFromPlayer();
    _historySaveTimer?.cancel();
    _historySaveTimer = null;
    _historyRefreshThrottle?.cancel();
    _historyRefreshThrottle = null;
    _disposeInlinePlayer();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vc = inlineVideoController.value;
    if (vc == null || !vc.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App 切后台/失焦 → 暂停播放，记录原状态用于恢复
        _wasPlayingBeforePause = vc.value.isPlaying;
        if (_wasPlayingBeforePause) {
          vc.pause();
        }
        // 同时暂停历史保存定时器，避免后台继续写 DB
        _historySaveTimer?.cancel();
        _historySaveTimer = null;
        break;
      case AppLifecycleState.resumed:
        // 切回前台 → 若之前在播放则恢复，并继续定时保存
        if (_wasPlayingBeforePause) {
          vc.play();
          _wasPlayingBeforePause = false;
        }
        if (inlineChewieController.value != null && _historySaveTimer == null) {
          _startHistorySaveTimer();
        }
        break;
      default:
        break;
    }
  }

  Future<void> loadDetail() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      // 并发拉取详情、收藏状态、续播位置
      final results = await Future.wait([
        _videoRepo.getVideoDetail(videoId),
        _favoriteRepo.isFavorited(videoId),
        _historyRepo.getByVideoId(videoId),
      ]);

      final d = results[0] as VideoDetail;

      // 先用列表页封面/标题占位（详情页 parser 不提取封面）
      Video video = d.video;
      if (video.coverUrl.isEmpty && initialCoverUrl.isNotEmpty) {
        video = video.copyWith(coverUrl: initialCoverUrl);
      }
      if (video.title.isEmpty && initialTitle.isNotEmpty) {
        video = video.copyWith(title: initialTitle);
      }

      // 同步缓存 + 合并元信息：
      // - VideoDetailParser 提取不到 playCount/likeCount/updateTime 时
      //   返回 0/0/''，cacheVideo 会用 VideoDao 中已缓存的列表页数据补全
      // - 返回的 merged Video 含完整元信息，回填到 detail.value.video
      //   让 UI 立即显示播放量/收藏数/发布时间等
      try {
        final merged = await _videoRepo.cacheVideo(video);
        video = merged;
      } catch (e) {
        appLogger.w('同步缓存 video 到 VideoDao 失败: $e');
      }

      detail.value = d.copyWith(video: video);
      isFavorited.value = results[1] as bool;
      final history = results[2] as PlayHistory?;
      if (history != null && !history.isCompleted) {
        initialPositionMs.value = history.positionMs;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleFavorite() async {
    final d = detail.value;
    if (d == null) return;
    final result = await _favoriteRepo.toggleFavorite(
      videoId: videoId,
      title: effectiveTitle,
      coverUrl: effectiveCoverUrl,
      categoryId: d.video.categoryId,
    );
    isFavorited.value = result;
  }

  // ===== 内联播放器逻辑 =====

  /// 用户点击详情页顶部"播放"按钮 → 启动内联播放
  ///
  /// 流程：
  /// 1. 标记已开始，UI 切换到 loading 态（封面 + 进度圈）
  /// 2. 调用 [UrlDecryptor.decryptPlayUrl] 拉取播放地址（含 fallback 兜底）
  /// 3. 用 [VideoPlayerController.networkUrl] 初始化
  /// 4. 创建 [ChewieController] 注入主题色，使用 MaterialControls 自带控件
  /// 5. autoPlay 自动播放
  ///
  /// 失败时 [inlineErrorMessage] 设置错误信息，UI 显示封面 + 重试按钮。
  Future<void> startInlinePlay() async {
    if (_inlineStarted) return;
    _inlineStarted = true;
    inlineLoading.value = true;
    inlineErrorMessage.value = '';

    try {
      // 复用已加载的 detail（含 AK token 时直接用，否则 url_decryptor 会重新拉取）
      final d = detail.value;
      final existingDetail =
          (d != null && d.token != null && d.token!.isNotEmpty) ? d : null;

      final result = await _decryptor.decryptPlayUrl(
        videoId,
        existingDetail: existingDetail,
      );

      // 同步更新 detail（若 url_decryptor 重新拉取过详情）
      if (d == null || d.token == null || d.token!.isEmpty || d.aid == null) {
        detail.value = result.detail;
      }

      final videoController = vp.VideoPlayerController.networkUrl(
        Uri.parse(result.playUrl),
        videoPlayerOptions: vp.VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      await videoController.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw const TimeoutException('视频初始化超时'),
          );

      // 续播：从历史记录的位置开始播放
      // 仅当历史进度 < 95%（未看完）且 > 5 秒时才 seek，避免从头开始的无效 seek
      final resumeMs = initialPositionMs.value;
      if (resumeMs > 5000) {
        try {
          await videoController.seekTo(Duration(milliseconds: resumeMs));
        } catch (e) {
          appLogger.w('续播 seekTo 失败，从头播放: $e');
        }
      }

      // 获取当前主题色（chewie 控件需在 build 时拿到主题色才能跟随切换）
      // 这里取默认 primary，实际颜色通过 Obx 在 UI 层重建 Chewie 时注入
      final chewie = _buildChewieController(videoController, autoPlay: true);
      inlineVideoController.value = videoController;
      inlineChewieController.value = chewie;
      inlineLoading.value = false;

      // 立即写入一次历史记录（position = 续播位置或 0）
      //
      // 用户需求：开始播放就出现在历史列表，不必等节流定时器首次触发。
      // 此时 videoController 已就绪但 duration 可能还在更新中，
      // _saveHistoryFromPlayer 内部会判断 duration > 0 才保存，
      // 因此这里直接调用即可（duration 0 时静默跳过，下一次定时器触发会写入）。
      _saveHistoryFromPlayer();

      // 启动历史记录节流保存定时器
      _startHistorySaveTimer();
    } on UrlExpiredException {
      inlineLoading.value = false;
      inlineErrorMessage.value = '播放地址已过期，请重试';
    } on DecryptException catch (e) {
      inlineLoading.value = false;
      inlineErrorMessage.value = e.message;
    } catch (e) {
      inlineLoading.value = false;
      inlineErrorMessage.value = '播放加载失败：$e';
      appLogger.e('内联播放器初始化失败', error: e);
    }
  }

  /// 重建 ChewieController（用于主题色切换后跟随重建）
  ///
  /// 保留当前播放位置与播放状态，仅替换 [ChewieController]。
  ChewieController _buildChewieController(
    vp.VideoPlayerController videoController, {
    required bool autoPlay,
  }) {
    return ChewieController(
      videoPlayerController: videoController,
      autoPlay: autoPlay,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      showControlsOnInitialize: true,
      // placeholder 在视频未初始化时显示封面（chewie 内置略缩图能力）
      placeholder: Container(color: Colors.black),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  /// 用户点击重试
  Future<void> retryInlinePlay() async {
    _historySaveTimer?.cancel();
    _historySaveTimer = null;
    _disposeInlinePlayer();
    _inlineStarted = false;
    await startInlinePlay();
  }

  void _disposeInlinePlayer() {
    try {
      inlineChewieController.value?.dispose();
    } catch (_) {}
    try {
      inlineVideoController.value?.dispose();
    } catch (_) {}
    inlineChewieController.value = null;
    inlineVideoController.value = null;
    _inlineStarted = false;
  }

  // ===== 历史记录节流保存 =====

  /// 启动定时保存播放进度的定时器
  ///
  /// 每 [_historySaveInterval]（5 秒）保存一次当前播放位置到数据库。
  /// 与 [onClose] 中的最后一次保存配合，确保续播位置准确。
  void _startHistorySaveTimer() {
    _historySaveTimer?.cancel();
    _historySaveTimer = Timer.periodic(_historySaveInterval, (_) {
      _saveHistoryFromPlayer();
    });
  }

  /// 从 video_player 当前状态读取 position/duration，写入播放历史
  ///
  /// 静默失败：若 videoController 未就绪或异常，直接返回（不影响播放）。
  /// duration 为 0 时跳过保存（避免误写 progress=1.0）。
  ///
  /// **实时同步 History Tab**：写入完成后调用 [_refreshHistoryController]，
  /// 让 HistoryController 的 RxList 立即更新，用户切到 History Tab 时
  /// 能看到最新播放记录和进度（无需等切换 Tab 触发 loadHistory）。
  void _saveHistoryFromPlayer() {
    final videoController = inlineVideoController.value;
    if (videoController == null || !videoController.value.isInitialized) {
      return;
    }
    final positionMs = videoController.value.position.inMilliseconds;
    final durationMs = videoController.value.duration.inMilliseconds;
    if (durationMs <= 0) return;

    final categoryId = detail.value?.video.categoryId ?? 0;
    // 异步执行，不阻塞当前调用方
    _historyRepo
        .upsertHistory(
      videoId: videoId,
      title: effectiveTitle,
      coverUrl: effectiveCoverUrl,
      categoryId: categoryId,
      positionMs: positionMs,
      durationMs: durationMs,
    )
        .then((_) => _refreshHistoryController())
        .catchError((e) {
      appLogger.w('保存播放历史失败: $e');
      return null;
    });
  }

  /// 同步刷新 HistoryController 的列表
  ///
  /// 使用 [Get.isRegistered] 防御性检查：
  /// - 测试环境或启动早期 HistoryController 未注册时不报错
  /// - 详情页可能在 History Tab 切换前就被打开
  ///
  /// 调用 [HistoryController.loadHistory] 会触发 RxList 重建，
  /// History Tab 的 Obx 自动重建 UI，实现"实时添加到播放历史列表"。
  ///
  /// **节流**：5s 保存周期内最多刷新一次 UI（2s 节流），避免 History Tab
  /// 频繁重建导致卡顿。最后一次刷新会在节流定时器触发时执行。
  void _refreshHistoryController() {
    if (!Get.isRegistered<HistoryController>()) return;
    // 已有待触发的节流定时器 → 不重复安排
    if (_historyRefreshThrottle?.isActive ?? false) return;
    _historyRefreshThrottle =
        Timer(const Duration(seconds: 2), () {
      if (!Get.isRegistered<HistoryController>()) return;
      Get.find<HistoryController>().loadHistory();
    });
  }
}
