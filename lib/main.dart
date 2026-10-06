import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:yellow_depot/presentation/pages/splash/splash_page.dart';

/// 应用入口
///
/// 启动流程（详见 [SplashPage] 文档）：
/// 1. WidgetsFlutterBinding.ensureInitialized()
/// 2. WakelockPlus.enable() — App 在前台时一直保持屏幕常亮
/// 3. runApp(SplashPage()) — 立即显示启动页，避免黑屏
/// 4. SplashPage 内部启动后台初始化任务：
///    - initializeApp()（数据 / 网络 / 主题）
///    - GitHubReleaseService.checkForUpdate()（检查更新）
///    - ApiServerSwitcher.fetchLatestDomain()（检查更新完成后获取最新域名）
///    - 等待至少 2 秒（避免快速加载导致闪屏）
/// 5. 有新版本 → 显示 UpdateDialog
///    无新版本 → 切换到 MainShell
///
/// **屏幕常亮说明**：
/// 之前在 PlayerPageController.onInit 中开启 wakelock，但用户反馈还是会息屏
/// （可能因为生命周期管理复杂，切后台再回来时 wakelock 失效）。
/// 现在改为 App 全局常亮：
/// - FLAG_KEEP_SCREEN_ON 只对前台 activity 有效，App 切到后台后系统会
///   自动息屏，不会浪费电
/// - App 在前台时任何页面都常亮，避免播放页生命周期管理导致 wakelock 失效
/// - wakelock_plus 无需 WAKE_LOCK 权限（使用 WindowManager flag）
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局绕过 HTTPS 证书校验
  //
  // 收藏 / 历史 / 视频卡片的封面图通过 cached_network_image 加载，它
  // 默认使用 Flutter 标准 HttpClient（不走 Dio），会对证书严格校验。
  // 源站图片 CDN 常存在自签名 / 过期 / 链路不完整等证书问题，浏览器
  // 允许"接受风险继续访问"，但 Flutter HttpClient 默认拒绝 → 图片加载失败。
  //
  // DioClient 已通过 `validateCertificate: (_, _, _) => true` 绕过校验，
  // 但那只对 Dio 实例有效，对 cached_network_image 的图片加载无效。
  // 这里设置全局 HttpOverrides，让所有 HttpClient（含图片加载）都绕过
  // 证书校验，与 Dio 行为保持一致。
  HttpOverrides.global = _BadCertHttpOverrides();

  // App 在前台时一直保持屏幕常亮
  WakelockPlus.enable();

  // 直接 runApp SplashPage — 同步立即渲染，避免黑屏
  // 初始化逻辑在 SplashPage 内部执行（StatefulWidget initState 触发）
  runApp(const SplashPage());
}

/// 全局 HTTP 覆盖：绕过 HTTPS 证书校验 + 强制 IPv4 连接。
///
/// 与 [DioClient] 的 `validateCertificate: (cert, host, port) => true`
/// 行为一致，让 cached_network_image 等非 Dio 客户端也能加载
/// 证书有问题的图片资源（源站图片 CDN 常见自签名 / 过期证书）。
///
/// **强制 IPv4**（2026-10-05）：
/// 部分 WiFi 网络（尤其 IPv6 优先的家庭 / 公共 WiFi）会先尝试 AAAA 记录，
/// 而源站仅 IPv4 或 IPv6 链路异常时，连接会挂起直至超时，表现为
/// 「数据网络正常，WiFi 无法获取数据」。强制仅解析 A 记录（IPv4）可
/// 避免此问题，对数据网络（通常返回 IPv4 或快速回退）同样兼容。
class _BadCertHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true
      ..connectionFactory = _forceIPv4Connection;
  }

  /// 强制 IPv4 连接工厂
  ///
  /// 解析主机名时仅查询 A 记录（IPv4），跳过 AAAA 记录（IPv6），
  /// 避免 IPv6 优先的 WiFi 网络下连接挂起问题。
  /// 代理场景下 [proxyHost] / [proxyPort] 非空，解析的是代理服务器地址。
  static Future<ConnectionTask<Socket>> _forceIPv4Connection(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  ) async {
    final host = proxyHost ?? url.host;
    final port = proxyPort ?? (url.port != 0
        ? url.port
        : (url.scheme == 'https' ? 443 : 80));
    final addresses = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    );
    if (addresses.isEmpty) {
      throw SocketException('IPv4 地址解析失败：$host');
    }
    return Socket.startConnect(addresses.first, port);
  }
}
