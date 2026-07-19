import 'package:get/get.dart';

/// 主 Shell 控制器 — 仅管理底部导航 currentIndex
///
/// 严格遵循 design-system/videohub/MASTER.md：
/// - 无业务逻辑
/// - 仅维护当前选中的 Tab index
class MainShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTab(int index) {
    if (index == currentIndex.value) return;
    currentIndex.value = index;
  }
}
