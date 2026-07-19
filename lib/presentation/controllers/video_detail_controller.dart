import 'package:get/get.dart';
import 'package:videohub/data/models/play_history.dart';
import 'package:videohub/data/models/video_detail.dart';
import 'package:videohub/data/repositories/favorite_repository.dart';
import 'package:videohub/data/repositories/history_repository.dart';
import 'package:videohub/data/repositories/video_repository.dart';

/// 视频详情控制器
class VideoDetailController extends GetxController {
  final VideoRepository _videoRepo;
  final FavoriteRepository _favoriteRepo;
  final HistoryRepository _historyRepo;

  VideoDetailController(
    this._videoRepo,
    this._favoriteRepo,
    this._historyRepo, {
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

  /// 跳转到播放页
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
}
