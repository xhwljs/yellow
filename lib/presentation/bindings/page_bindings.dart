import 'package:get/get.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';
import 'package:yellow_depot/core/player/url_decryptor.dart';
import 'package:yellow_depot/presentation/controllers/category_controller.dart';
import 'package:yellow_depot/presentation/controllers/search_controller.dart';
import 'package:yellow_depot/presentation/controllers/video_detail_controller.dart';
import 'package:yellow_depot/presentation/controllers/video_player_controller.dart';

/// 分类页 Binding
///
/// **每次 push 都重建 CategoryController**：
/// 旧版用 `Get.lazyPut` 是 lazy 单例，第二次从卷帘菜单切换到不同 categoryId
/// 时会复用旧实例（categoryId 不变），导致显示的还是旧分类内容。
/// 现在改为：先 `Get.delete` 清掉旧实例（如存在），再 `Get.put` 创建新实例，
/// 保证每次进入分类页都从该分类的第一页开始加载。
class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    final categoryId = int.tryParse(Get.arguments.toString()) ?? 0;
    // 清掉旧实例（路由 pop 时可能未释放）
    if (Get.isRegistered<CategoryController>()) {
      Get.delete<CategoryController>();
    }
    Get.put<CategoryController>(
      CategoryController(
        Get.find<VideoRepository>(),
        categoryId: categoryId,
      ),
      permanent: false,
    );
  }
}

/// 搜索页 Binding
///
/// 每次进入搜索页都创建新实例，重置搜索关键字与结果列表
/// （旧版 lazyPut 单例会保留上一次搜索结果，体验不直观）。
class SearchBinding extends Bindings {
  @override
  void dependencies() {
    if (Get.isRegistered<SearchController>()) {
      Get.delete<SearchController>();
    }
    Get.put<SearchController>(
      SearchController(Get.find<VideoRepository>()),
      permanent: false,
    );
  }
}

/// 视频详情页 Binding
///
/// arguments 支持：
/// - String（仅 videoId，旧路径）
/// - Map：{ videoId, coverUrl?, title? } 列表页传入的初始封面/标题
class VideoDetailBinding extends Bindings {
  @override
  void dependencies() {
    String videoId;
    String initialCoverUrl = '';
    String initialTitle = '';

    if (Get.arguments is String) {
      videoId = Get.arguments as String;
    } else if (Get.arguments is Map) {
      videoId = Get.arguments['videoId'] as String? ?? '';
      initialCoverUrl = Get.arguments['coverUrl'] as String? ?? '';
      initialTitle = Get.arguments['title'] as String? ?? '';
    } else {
      videoId = '';
    }

    Get.lazyPut<VideoDetailController>(
      () => VideoDetailController(
        Get.find<VideoRepository>(),
        Get.find<FavoriteRepository>(),
        Get.find<HistoryRepository>(),
        Get.find<UrlDecryptor>(),
        videoId: videoId,
        initialCoverUrl: initialCoverUrl,
        initialTitle: initialTitle,
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
