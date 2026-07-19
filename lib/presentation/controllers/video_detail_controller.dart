import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:videohub/core/error/exceptions.dart';
import 'package:videohub/core/player/url_decryptor.dart';
import 'package:videohub/core/utils/logger.dart';
import 'package:videohub/data/models/play_history.dart';
import 'package:videohub/data/models/video_detail.dart';
import 'package:videohub/data/repositories/favorite_repository.dart';
import 'package:videohub/data/repositories/history_repository.dart';
import 'package:videohub/data/repositories/video_repository.dart';

/// 视频详情控制器
///
/// 包含两个独立播放入口：
/// 1. **顶部内联播放器**（[inlineVideoController]/[inlineChewieController]）：
///    在详情页 SliverAppBar 区域直接播放，使用 chewie 自带控件。
/// 2. **FAB 全屏跳转**（[goToPlayer]）：跳转到独立的 VideoPlayerPage 沉浸式播放，
///    支持手势 / 倍速 / 进度续播。两个入口互不影响。
class VideoDetailController extends GetxController {
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
    loadDetail();
  }

  @override
  void onClose() {
    _disposeInlinePlayer();
    super.onClose();
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
      // 用列表页封面覆盖（详情页 parser 不提取封面）
      if (d.video.coverUrl.isEmpty && initialCoverUrl.isNotEmpty) {
        detail.value = d.copyWith(
          video: d.video.copyWith(coverUrl: initialCoverUrl),
        );
      } else {
        detail.value = d;
      }
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

      // 获取当前主题色（chewie 控件需在 build 时拿到主题色才能跟随切换）
      // 这里取默认 primary，实际颜色通过 Obx 在 UI 层重建 Chewie 时注入
      final chewie = _buildChewieController(videoController, autoPlay: true);
      inlineVideoController.value = videoController;
      inlineChewieController.value = chewie;
      inlineLoading.value = false;
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
    _disposeInlinePlayer();
    _inlineStarted = false;
    await startInlinePlay();
  }

  /// 跳转到全屏播放页（保留现有逻辑，不受内联播放器影响）
  void goToPlayer() {
    final d = detail.value;
    if (d == null) return;
    Get.toNamed(
      '/player',
      arguments: {
        'videoId': videoId,
        'title': effectiveTitle,
        'coverUrl': effectiveCoverUrl,
        'categoryId': d.video.categoryId,
        'initialPositionMs': initialPositionMs.value,
        'existingDetail': d,
      },
    );
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
}
