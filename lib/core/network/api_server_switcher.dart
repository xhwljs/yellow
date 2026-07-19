import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/network/dio_client.dart';

/// API 服务器切换工具
///
/// 源站域名可能因反爬频繁更换（如 555973.xyz → 555974.xyz → 555975.xyz ...），
/// 提供运行时切换 + 持久化 + Dio 重建能力，避免每次换域名都要发版。
class ApiServerSwitcher {
  ApiServerSwitcher._();

  /// 内置推荐镜像列表（用户可在设置页一键切换）
  ///
  /// 实测（2026-07-19）：
  /// - 555975.xyz ✅ 当前真实源站
  /// - 555972.xyz ⚠️ 未验证，保留作为候选
  /// - 555974.xyz ❌ 已变跳转壳（→ cktongji.com:8899 → 404），列入 [_deadMirrors]
  /// - 555973.xyz ❌ 已是跳转壳
  static const List<String> presetMirrors = [
    'http://555975.xyz',
    'http://555972.xyz',
  ];

  /// 已知失效镜像列表
  ///
  /// 用于 [loadFromPrefs] 自动迁移：用户旧版 App 持久化过这些 URL，
  /// 升级后启动时若检测到，自动回退到 [AppConstants.defaultBaseUrl]。
  static const List<String> _deadMirrors = [
    'http://555974.xyz',
    'http://555973.xyz',
  ];

  /// 当前生效的 baseUrl
  static String get current => AppConstants.baseUrl;

  /// 从 SharedPreferences 加载用户保存的 baseUrl（应用启动时调用）
  ///
  /// **自动迁移**：若用户旧版持久化了已知失效镜像（[ _deadMirrors]），
  /// 自动回退到 [AppConstants.defaultBaseUrl] 并更新持久化值，
  /// 避免用户在死链上一直拿不到内容（这是 AK Token 提取失败的最常见根因）。
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyApiBaseUrl);
    if (saved == null || saved.isEmpty) return;

    // 自动迁移死链
    if (_deadMirrors.contains(saved)) {
      await prefs.setString(
        AppConstants.keyApiBaseUrl,
        AppConstants.defaultBaseUrl,
      );
      AppConstants.baseUrl = AppConstants.defaultBaseUrl;
      return;
    }

    AppConstants.baseUrl = saved;
  }

  /// 切换到新 baseUrl
  ///
  /// 1. 持久化到 SharedPreferences
  /// 2. 更新 AppConstants.baseUrl
  /// 3. 重建 Dio 实例（保留所有拦截器，仅替换 baseUrl）
  ///
  /// 返回旧 baseUrl 供 UI 提示。
  static Future<String> switchTo(String newBaseUrl) async {
    final old = AppConstants.baseUrl;
    if (newBaseUrl == old) return old;

    // 1. 持久化
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyApiBaseUrl, newBaseUrl);

    // 2. 更新全局常量
    AppConstants.baseUrl = newBaseUrl;

    // 3. 重建 Dio
    await DioClient.rebuildWithBaseUrl(newBaseUrl);

    return old;
  }

  /// 重置为默认 baseUrl
  static Future<void> resetToDefault() async {
    await switchTo(AppConstants.defaultBaseUrl);
  }

  /// 清除 SharedPreferences 中保存的 baseUrl（应用卸载/重置场景）
  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyApiBaseUrl);
  }

  /// 简单连通性测试（HEAD 请求）
  ///
  /// 返回 null 表示成功，否则返回错误信息。
  static Future<String?> testConnectivity(String baseUrl) async {
    try {
      final testDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
      );
      final resp = await testDio.head<String>('/');
      testDio.close();
      if (resp.statusCode != null && resp.statusCode! >= 200) {
        return null;
      }
      return 'HTTP ${resp.statusCode}';
    } on DioException catch (e) {
      return e.message ?? e.type.name;
    } catch (e) {
      return e.toString();
    }
  }
}
