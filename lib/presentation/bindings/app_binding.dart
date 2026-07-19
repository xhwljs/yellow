import 'package:get/get.dart';
import 'package:videohub/core/network/api_service.dart';
import 'package:videohub/core/network/dio_client.dart';
import 'package:videohub/core/player/url_decryptor.dart';
import 'package:videohub/core/theme/theme_controller.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/data/repositories/category_repository.dart';
import 'package:videohub/data/repositories/favorite_repository.dart';
import 'package:videohub/data/repositories/history_repository.dart';
import 'package:videohub/data/repositories/video_repository.dart';
import 'package:videohub/presentation/controllers/favorites_controller.dart';
import 'package:videohub/presentation/controllers/history_controller.dart';
import 'package:videohub/presentation/controllers/home_controller.dart';
import 'package:videohub/presentation/controllers/main_shell_controller.dart';

/// 应用初始化（在 runApp 之前调用）
///
/// 严格按依赖顺序注入：
/// 1. Dio 客户端
/// 2. ApiService
/// 3. AppDatabase (Floor)
/// 4. 4 个 Repository
/// 5. 全局 Controller（Theme / MainShell / Home / Favorites / History）
/// 6. UrlDecryptor
Future<void> initializeApp() async {
  // 1. Dio
  await DioClient.ensureInitialized();

  // 2. ApiService
  Get.put<ApiService>(ApiService(), permanent: true);

  // 3. 数据库
  final database = await AppDatabase.build();
  Get.put<AppDatabase>(database, permanent: true);

  // 4. Repository
  Get.put<CategoryRepository>(
    CategoryRepository(Get.find<ApiService>(), Get.find<AppDatabase>()),
    permanent: true,
  );
  Get.put<VideoRepository>(
    VideoRepository(Get.find<ApiService>(), Get.find<AppDatabase>()),
    permanent: true,
  );
  Get.put<HistoryRepository>(
    HistoryRepository(Get.find<AppDatabase>()),
    permanent: true,
  );
  Get.put<FavoriteRepository>(
    FavoriteRepository(Get.find<AppDatabase>()),
    permanent: true,
  );

  // 5. 解密器
  Get.put<UrlDecryptor>(
    UrlDecryptor(Get.find<ApiService>()),
    permanent: true,
  );

  // 6. 全局控制器
  final themeController = ThemeController();
  themeController.onInit();
  Get.put<ThemeController>(themeController, permanent: true);
  Get.put<MainShellController>(MainShellController(), permanent: true);

  // 7. Shell 内 3 个常驻控制器
  Get.put<HomeController>(
    HomeController(
      Get.find<CategoryRepository>(),
      Get.find<VideoRepository>(),
    ),
    permanent: true,
  );
  Get.put<FavoritesController>(
    FavoritesController(Get.find<FavoriteRepository>()),
    permanent: true,
  );
  Get.put<HistoryController>(
    HistoryController(Get.find<HistoryRepository>()),
    permanent: true,
  );
}
