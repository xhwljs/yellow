import 'package:get/get.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/favorite.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';

/// 收藏控制器
class FavoritesController extends GetxController {
  final FavoriteRepository _favoriteRepo;
  FavoritesController(this._favoriteRepo);

  final RxList<Favorite> favorites = <Favorite>[].obs;
  final RxBool isLoading = false.obs;

  /// 加载失败时的错误信息（非空表示当前处于错误态）
  ///
  /// UI 层据此展示 [ErrorView] + 重试按钮，避免静默失败让用户误以为"无收藏"。
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await _favoriteRepo.getAllFavorites();
      favorites.value = result;
    } catch (e, st) {
      appLogger.e('loadFavorites failed', error: e, stackTrace: st);
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeFavorite(String videoId) async {
    await _favoriteRepo.removeFavorite(videoId);
    favorites.removeWhere((f) => f.videoId == videoId);
  }
}
