import 'package:get/get.dart';
import 'package:yellow_depot/data/models/favorite.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';

/// 收藏控制器
class FavoritesController extends GetxController {
  final FavoriteRepository _favoriteRepo;
  FavoritesController(this._favoriteRepo);

  final RxList<Favorite> favorites = <Favorite>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    isLoading.value = true;
    try {
      final result = await _favoriteRepo.getAllFavorites();
      favorites.value = result;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeFavorite(String videoId) async {
    await _favoriteRepo.removeFavorite(videoId);
    favorites.removeWhere((f) => f.videoId == videoId);
  }
}
