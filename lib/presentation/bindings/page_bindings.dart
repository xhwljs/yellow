import 'package:get/get.dart';
import 'package:videohub/data/repositories/video_repository.dart';
import 'package:videohub/data/repositories/favorite_repository.dart';
import 'package:videohub/data/repositories/history_repository.dart';
import 'package:videohub/core/player/url_decryptor.dart';
import 'package:videohub/presentation/controllers/category_controller.dart';
import 'package:videohub/presentation/controllers/video_detail_controller.dart';
import 'package:videohub/presentation/controllers/video_player_controller.dart';

/// 分类页 Binding
class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    final categoryId = int.tryParse(Get.arguments.toString()) ?? 0;
    Get.lazyPut<CategoryController>(
      () => CategoryController(
        Get.find<VideoRepository>(),
        categoryId: categoryId,
      ),
    );
  }
}

/// 视频详情页 Binding
class VideoDetailBinding extends Bindings {
  @override
  void dependencies() {
    final videoId = Get.arguments is String
        ? Get.arguments as String
        : Get.arguments['videoId'] as String? ?? '';
    Get.lazyPut<VideoDetailController>(
      () => VideoDetailController(
        Get.find<VideoRepository>(),
        Get.find<FavoriteRepository>(),
        Get.find<HistoryRepository>(),
        videoId: videoId,
      ),
    );
  }
}

/// 播放器页 Binding
class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    final args =
        Get.arguments is Map ? Get.arguments as Map : <String, dynamic>{};

    Get.lazyPut<PlayerPageController>(
      () => PlayerPageController(
        args: PlayerArgs(
          videoId: args['videoId'] as String? ?? '',
          title: args['title'] as String? ?? '',
          coverUrl: args['coverUrl'] as String? ?? '',
          categoryId: args['categoryId'] as int? ?? 0,
          initialPositionMs: args['initialPositionMs'] as int? ?? 0,
          durationMs: args['durationMs'] as int?,
          existingDetail: args['existingDetail'],
        ),
        decryptor: Get.find<UrlDecryptor>(),
        historyRepo: Get.find<HistoryRepository>(),
      ),
    );
  }
}
