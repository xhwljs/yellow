import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

/// 连续两秒内按两次返回键退出 App 的 wrapper
///
/// **使用场景**：
/// App 在 MainShell 的 4 个 Tab（首页 / 收藏 / 历史 / 设置）中按系统返回键时，
/// 不直接退出 App，而是显示"再按一次退出应用"提示；连续两秒内再按一次才退出。
///
/// **为什么放在 MainShell 而非每个 Tab**：
/// MainShell 的 4 个 Tab 用 IndexedStack 渲染，切换 Tab 不 push 路由，
/// 按返回键都是在 MainShell（栈底）触发。放一处即可覆盖所有 4 个 Tab。
///
/// **子路由不受影响**：
/// 当 detail / category / search / player 等子路由在栈顶时，按返回键由
/// 子路由处理 pop，不会触发本 wrapper 的 PopScope（因为 PopScope 仅在
/// _ShellBody 是栈顶时触发，didPop=false 分支才会进入"两次返回键"检测）。
///
/// 用法：
/// ```dart
/// return BackPressExitWrapper(
///   child: Scaffold(...),
/// );
/// ```
class BackPressExitWrapper extends StatefulWidget {
  final Widget child;

  const BackPressExitWrapper({super.key, required this.child});

  @override
  State<BackPressExitWrapper> createState() => _BackPressExitWrapperState();
}

class _BackPressExitWrapperState extends State<BackPressExitWrapper> {
  DateTime? _lastPressed;

  /// 两次按返回键的最大间隔，超过则重新计时
  static const Duration _exitTimeout = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop=false 拦截系统返回键，由我们自己处理
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // didPop=true 表示已经 pop（子路由场景），不拦截
        if (didPop) return;
        _handleBackPress();
      },
      child: widget.child,
    );
  }

  void _handleBackPress() {
    final now = DateTime.now();
    if (_lastPressed == null ||
        now.difference(_lastPressed!) > _exitTimeout) {
      // 第一次按 / 超时后第一次按 → 显示提示
      _lastPressed = now;
      _showExitToast();
      return;
    }
    // 连续两秒内第二次按 → 退出 App
    // SystemNavigator.pop() 是 Flutter 推荐的退出方式，
    // Android 上等价于 finish activity，iOS 上 Apple 不允许 App 主动退出
    // （但 iOS 没有"返回键"场景，本逻辑只在 Android 生效）
    SystemNavigator.pop();
  }

  /// 显示"再按一次退出"提示
  ///
  /// 用 Get.snackbar 实现，snackPosition BOTTOM，
  /// duration 与 _exitTimeout 一致（2 秒后自动消失）。
  void _showExitToast() {
    final colors = AppTheme.colorsOf(Get.context!);
    Get.snackbar(
      '',
      '',
      messageText: Text(
        '再按一次退出应用',
        style: TextStyle(
          color: colors.onSurface,
          fontSize: DesignTokens.textBody,
        ),
      ),
      snackPosition: SnackPosition.BOTTOM,
      duration: _exitTimeout,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceSm,
      ),
      backgroundColor: colors.surface,
      borderRadius: DesignTokens.radiusMd,
      borderColor: colors.border,
      borderWidth: 1,
      isDismissible: false,
      dismissDirection: DismissDirection.none,
      // 不显示标题左侧的 icon（默认 GetX snackbar 有 icon 占位）
      icon: const SizedBox.shrink(),
      // 不该让 snackbar 抢焦点影响"两次返回键"检测
      shouldIconPulse: false,
      // 进度条隐藏
      showProgressIndicator: false,
      // 不让用户点击 dismiss（避免误触）
      onTap: (_) {},
      overlayBlur: 0,
    );
  }
}
