import 'dart:async';

import 'package:flutter/services.dart';
import 'package:yellow_depot/core/utils/logger.dart';

/// 画中画服务（N7：Android 原生 PiP 桥接）
///
/// 通信协议（MethodChannel `pip_channel`）：
/// - Flutter → 原生：
///   - `setPipEnabled {enabled, aspectRatio}`：标记当前是否允许自动进 PiP
///     （播放页开始播放时 enable，离开时 disable）。
///     原生在 `onUserLeaveHint`（用户按 Home / 切后台）时检查该标记，
///     允许则以视频宽高比进入画中画小窗
///   - `enterPip`：主动进入 PiP（预留）
/// - 原生 → Flutter：
///   - `onPipChanged {bool}`：进入 / 退出 PiP 时反向通知，
///     UI 层订阅 [onPipChanged] 切换纯视频布局
///
/// 降级：非 Android 平台 / 原生未注入（MissingPluginException）时静默跳过。
class PipService {
  PipService._();

  static const MethodChannel _channel = MethodChannel('pip_channel');

  /// PiP 状态变化流（true = 当前处于画中画小窗）
  static final StreamController<bool> _pipChangedController =
      StreamController<bool>.broadcast();

  static Stream<bool> get onPipChanged => _pipChangedController.stream;

  static bool _handlerReady = false;

  /// 注册原生回调（幂等；首次 enable 时自动调用）
  static void _ensureHandler() {
    if (_handlerReady) return;
    _handlerReady = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final isInPip = call.arguments as bool? ?? false;
        _pipChangedController.add(isInPip);
        appLogger.i('PiP 状态变化: $isInPip');
      }
      return null;
    });
  }

  /// 允许自动进入画中画（播放页开始播放时调用）
  ///
  /// [aspectRatio] 视频宽高比（w/h，如 1.777），
  /// 用于 PiP 小窗形状匹配（原生侧 clamp 到系统允许范围）。
  static Future<void> enable(double aspectRatio) async {
    _ensureHandler();
    try {
      await _channel.invokeMethod('setPipEnabled', {
        'enabled': true,
        'aspectRatio': aspectRatio,
      });
    } on MissingPluginException {
      // 非 Android / 原生未注入 → 静默降级
    } on PlatformException catch (e) {
      appLogger.w('PipService.enable 失败: ${e.message}');
    }
  }

  /// 取消自动进入画中画（离开播放页时调用）
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('setPipEnabled', {
        'enabled': false,
      });
    } on MissingPluginException {
      // 静默降级
    } on PlatformException catch (e) {
      appLogger.w('PipService.disable 失败: ${e.message}');
    }
  }

  /// 主动进入画中画（预留扩展，当前用自动模式）
  static Future<bool> enterPip() async {
    try {
      final ok = await _channel.invokeMethod<bool>('enterPip');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
