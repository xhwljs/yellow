import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/theme/app_theme.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

/// 连续两秒内按两次返回键退出 App 的 wrapper
///
/// **使用场景**：
/// App 在 MainShell 的 4 个 Tab（首页 / 收藏 / 历史 / 设置）中按系统返回键时，
/// 不直接退出 App，而是显示"再按一次退出应用"浮动提示；连续两秒内再按
/// 一次才退出。
///
/// **为什么放在 MainShell 而非每个 Tab**：
/// MainShell 的 4 个 Tab 用 IndexedStack 渲染，切换 Tab 不 push 路由，
/// 按返回键都是在 MainShell（栈底）触发。放一处即可覆盖所有 4 个 Tab。
///
/// **子路由不受影响**：
/// 当 detail / category / search / player 等子路由在栈顶时，按返回键由
/// 子路由处理 pop，不会触发本 wrapper 的 PopScope。
///
/// **提示设计**（不用 Get.snackbar）：
/// 用 OverlayEntry 自定义浮动 Toast，定位在屏幕底部、BottomNavigationBar 上方：
///   - 底部对齐符合"退出应用"的语义习惯（用户期望从底部退出）
///   - 通过固定 bottom inset（88dp）避开 BottomNavigationBar，不遮挡 tab 页
///   - 圆角卡片 + 阴影 + 倒计时进度环（让用户感知 2 秒窗口剩余时间，
///     符合 UX "Active States" + "Toast Notifications" 原则）
///   - 进入 fade+scale（200ms easeOutCubic），退出 fade out（150ms）
///   - 2 秒窗口结束自动消失
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

  /// 当前显示的浮动 Toast（同一时刻只允许一个）
  OverlayEntry? _toastEntry;

  @override
  void dispose() {
    _removeToast();
    super.dispose();
  }

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
    _removeToast();
    SystemNavigator.pop();
  }

  /// 显示"再按一次退出"浮动 Toast
  ///
  /// 设计要点：
  /// - OverlayEntry 浮在根 Overlay 顶层，独立于 Scaffold 的 snackbar 队列
  /// - 定位在屏幕中央（SafeArea 内），避开 AppBar 和 BottomNavigationBar
  /// - 倒计时进度环 + 自动消失动画由 _ExitToast 内部 AnimationController 驱动
  /// - 动画播放完成后由 onDismissed 回调 remove OverlayEntry
  void _showExitToast() {
    _removeToast();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _ExitToast(
        timeout: _exitTimeout,
        onDismissed: () {
          // 只移除自己（防止移除后被替换的新 Toast）
          if (_toastEntry != null) {
            _toastEntry!.remove();
            _toastEntry = null;
          }
        },
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
  }

  /// 立即移除当前 Toast（用于退出 App 或重新显示前清场）
  void _removeToast() {
    if (_toastEntry != null) {
      _toastEntry!.remove();
      _toastEntry = null;
    }
  }
}

/// "再按一次退出应用"浮动 Toast
///
/// **布局**：屏幕底部、BottomNavigationBar 上方
///   - bottom inset = _bottomInset，避开 BottomNavigationBar（不遮挡 tab）
///   - SafeArea 处理底部手势条
///   - IgnorePointer 不拦截下层手势（用户可继续操作 tab 页）
///
/// **视觉**：
///   - 圆角卡片（radiusLg）+ 阴影（24 blur, 8 y offset）
///   - 左侧 28×28 倒计时进度环（primary 色）+ 中心 signOut 图标
///   - 右侧 "再按一次退出应用" 文本（textBody + w600 + onSurface）
///
/// **动画**（由 AnimationController 正向/反向驱动）：
///   - 进入（0-15%）：fade 0→1 + scale 0.85→1.0，easeOutCubic
///   - 保持（15-100%）：进度环从满倒计时到空
///   - 退出：controller 反向播放 fade out（150ms easeIn），完成后 onDismissed
class _ExitToast extends StatefulWidget {
  final Duration timeout;
  final VoidCallback onDismissed;

  const _ExitToast({
    required this.timeout,
    required this.onDismissed,
  });

  @override
  State<_ExitToast> createState() => _ExitToastState();
}

class _ExitToastState extends State<_ExitToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 进入动画占比（前 15% 的时间用于 fade+scale，剩余 85% 倒计时进度环）
  static const double _enterRatio = 0.15;

  /// Toast 距离屏幕底部的偏移（避开 BottomNavigationBar）
  ///
  /// MainShell 的 BottomNavigationBar 为 fixed 类型 + 显示 label，
  /// 标准高度约 80dp（含 icon + label + padding）。
  /// 在 root Overlay 层级（全屏），SafeArea 处理手势条后，
  /// 再加 80dp 把 Toast 推到 BottomNavigationBar 上方，
  /// + 8dp margin 让 Toast 不紧贴 tab bar 顶部。
  static const double _bottomInset = 88;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.timeout,
    );

    // 正向播放完成后：反向快速 fade out，然后 onDismissed
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 反向播放做 fade out（duration 缩到 150ms）
        _controller.duration = const Duration(milliseconds: 150);
        _controller.reverse(from: 1.0).then((_) {
          widget.onDismissed();
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    // 进入段（0 ~ _enterRatio）：opacity 0→1, scale 0.85→1.0
    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, _enterRatio, curve: Curves.easeOut),
      ),
    );
    final scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, _enterRatio, curve: Curves.easeOutCubic),
      ),
    );

    // 倒计时进度环：1.0 → 0.0（贯穿整个正向播放过程）
    final progressAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linear),
      ),
    );

    return Positioned(
      // 不指定 top：让 Toast 自然高度向上展开，定位在屏幕底部
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        // SafeArea 处理底部手势条（root Overlay 全屏，需要手动避开）
        child: Padding(
          padding: const EdgeInsets.only(bottom: _bottomInset),
          // IgnorePointer 让 Toast 不拦截下层手势 — 用户可以在 Toast 显示期间
          // 继续操作 tab 页（如继续滑动列表），仅按返回键才会触发"再次按"逻辑
          child: IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => Opacity(
                  opacity: fadeAnim.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scaleAnim.value,
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceLg,
                      vertical: DesignTokens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusLg),
                      // 阴影：onSurface 18% 透明 + 24 blur + 8 y offset
                      // 符合 Material Elevation 3 的视觉重量
                      boxShadow: [
                        BoxShadow(
                          color: colors.onSurface.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 倒计时进度环 + 中心退出图标
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progressAnim.value.clamp(0.0, 1.0),
                                strokeWidth: 2.5,
                                backgroundColor: colors.border,
                                valueColor: AlwaysStoppedAnimation(
                                  colors.primary,
                                ),
                              ),
                              Icon(
                                PhosphorIconsFill.signOut,
                                size: 14,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceMd),
                        Text(
                          '再按一次退出应用',
                          style: TextStyle(
                            fontSize: DesignTokens.textBody,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
