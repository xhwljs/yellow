import 'package:get/get.dart';
import 'package:videohub/presentation/bindings/page_bindings.dart';
import 'package:videohub/presentation/pages/category/category_page.dart';
import 'package:videohub/presentation/pages/detail/video_detail_page.dart';
import 'package:videohub/presentation/pages/player/video_player_page.dart';
import 'package:videohub/presentation/pages/search/search_page.dart';

/// 路由配置
class AppPages {
  AppPages._();

  static const String initial = '/';
  static const String category = '/category';
  static const String detail = '/detail';
  static const String player = '/player';
  static const String search = '/search';

  static final List<GetPage> routes = [
    GetPage(
      name: category,
      page: () => const CategoryPage(),
      binding: CategoryBinding(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: search,
      page: () => const SearchPage(),
      binding: SearchBinding(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: detail,
      page: () => const VideoDetailPage(),
      binding: VideoDetailBinding(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: player,
      page: () => const VideoPlayerPage(),
      binding: PlayerBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      fullscreenDialog: true,
    ),
  ];
}
