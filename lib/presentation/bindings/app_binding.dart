import 'package:get/get.dart';
import 'package:yellow_depot/core/network/api_server_switcher.dart';
import 'package:yellow_depot/core/network/api_service.dart';
import 'package:yellow_depot/core/network/dio_client.dart';
import 'package:yellow_depot/core/player/url_decryptor.dart';
import 'package:yellow_depot/core/theme/theme_controller.dart';
import 'package:yellow_depot/data/database/app_database.dart';
import 'package:yellow_depot/data/repositories/category_repository.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';
import 'package:yellow_depot/data/repositories/video_repository.dart';
import 'package:yellow_depot/presentation/controllers/favorites_controller.dart';
import 'package:yellow_depot/presentation/controllers/history_controller.dart';
import 'package:yellow_depot/presentation/controllers/home_controller.dart';
import 'package:yellow_depot/presentation/controllers/main_shell_controller.dart';

/// 应用初始化（在 runApp 之前调用）
///
/// 严格按依赖顺序注入：
/// 1. ApiServerSwitcher.loadFromPrefs 加载用户覆盖的 baseUrl（含死链自动迁移）
/// 2. Dio 客户端
/// 3. ApiService
/// 4. AppDatabase (Floor)
/// 5. 4 个 Repository
/// 6. 全局 Controller（Theme / MainShell / Home / Favorites / History）
/// 7. UrlDecryptor
Future<void> initializeApp() async {
  // 1. 加载用户保存的 baseUrl（含死链自动迁移到 defaultBaseUrl）
  //
  // 重要：必须通过 ApiServerSwitcher.loadFromPrefs，它会检查旧版本持久化的
  // 已知失效镜像（如 555974.xyz）并自动迁移。直接读 SharedPreferences 会绕过
  // 这个迁移逻辑，导致用户升级后仍死链拿不到 AK Token。
  await ApiServerSwitcher.loadFromPrefs();

  // 2. Dio
  await DioClient.ensureInitialized();

  // 3. ApiService
  Get.put<ApiService>(ApiService(), permanent: true);

  // 4. 数据库
  final database = await AppDatabase.build();
  Get.put<AppDatabase>(database, permanent: true);

  // 5. Repository
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

  // 6. 解密器
  Get.put<UrlDecryptor>(
    UrlDecryptor(Get.find<ApiService>()),
    permanent: true,
  );

  // 7. 全局控制器
  final themeController = ThemeController();
  themeController.onInit();
  Get.put<ThemeController>(themeController, permanent: true);
  Get.put<MainShellController>(MainShellController(), permanent: true);

  // 8. Shell 内 3 个常驻控制器
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
