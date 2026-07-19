import 'package:get/get.dart';
import 'package:videohub/presentation/controllers/favorites_controller.dart';
import 'package:videohub/presentation/controllers/history_controller.dart';

/// 主 Shell 控制器 — 管理底部导航 currentIndex + Tab 切换时刷新数据
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 无业务逻辑
/// - 仅维护当前选中的 Tab index
///
/// **Tab 切换刷新机制**：
/// 由于 MainShell 使用 IndexedStack（所有 Tab 页面在 App 启动时就构建），
/// 各 Tab 的 controller 在启动时 onInit 一次，加载初始数据后不再重载。
/// 这会导致用户在详情页收藏 / 播放视频后，切到 Favorites / History Tab 时
/// 看不到最新数据。
///
/// 修复：在 [changeTab] 中，切到 Favorites(1) / History(2) 时，
/// 主动调用对应 controller 的 loadXxx() 方法刷新列表。
class MainShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTab(int index) {
    if (index == currentIndex.value) return;
    currentIndex.value = index;
    _refreshTabData(index);
  }

  /// 切换到指定 Tab 后刷新对应 controller 的数据
  ///
  /// 使用 Get.isRegistered 防御性检查，避免在测试 / 启动早期
  /// controller 尚未注册时报错。
  void _refreshTabData(int index) {
    switch (index) {
      case 1:
        // 收藏页 — 重新加载收藏列表
        if (Get.isRegistered<FavoritesController>()) {
          Get.find<FavoritesController>().loadFavorites();
        }
        break;
      case 2:
        // 历史页 — 重新加载播放历史
        if (Get.isRegistered<HistoryController>()) {
          Get.find<HistoryController>().loadHistory();
        }
        break;
      default:
        // 首页 / 设置页无需刷新
        break;
    }
  }
}
