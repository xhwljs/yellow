import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/network/dio_client.dart';
import 'package:videohub/data/database/app_database.dart';
import 'package:videohub/presentation/controllers/favorites_controller.dart';
import 'package:videohub/presentation/controllers/history_controller.dart';
import 'package:videohub/presentation/controllers/home_controller.dart';

/// API 服务器切换工具
///
/// 源站域名可能因反爬频繁更换（如 555973.xyz → 555974.xyz → 555975.xyz ...），
/// 提供运行时切换 + 持久化 + Dio 重建 + 数据刷新通知能力，避免每次换域名都要发版。
///
/// **切换后刷新机制**：
/// - 切换 baseUrl 后，本地 DB 中缓存的 categories / videos 来自旧源站，
///   其相对路径在新源站下虽可用，但封面图等资源 URL 可能仍是旧域名导致失效。
///   因此切换时清空本地缓存，并主动调用 HomeController.refresh() 强制刷新首页。
/// - 历史记录 / 收藏夹不依赖 baseUrl，但切换后也刷新一次让 UI 同步。
class ApiServerSwitcher {
  ApiServerSwitcher._();

  /// 内置推荐镜像列表（用户可在设置页一键切换）
  ///
  /// 实测（2026-07-19）：
  /// - 555976.xyz ✅ 当前真实源站
  /// - 555972.xyz ⚠️ 未验证，保留作为候选
  /// - 555975.xyz ❌ 已变跳转壳，列入 [_deadMirrors]
  /// - 555974.xyz ❌ 已变跳转壳，列入 [_deadMirrors]
  /// - 555973.xyz ❌ 已是跳转壳
  static const List<String> presetMirrors = [
    'http://555976.xyz',
    'http://555972.xyz',
  ];

  /// 已知失效镜像列表
  ///
  /// 用于 [loadFromPrefs] 自动迁移：用户旧版 App 持久化过这些 URL，
  /// 升级后启动时若检测到，自动回退到 [AppConstants.defaultBaseUrl]，
  /// 避免用户在死链上一直拿不到内容（这是 AK Token 提取失败的最常见根因）。
  static const List<String> _deadMirrors = [
    'http://555975.xyz',
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
  /// 完整流程：
  /// 1. 持久化到 SharedPreferences
  /// 2. 更新 AppConstants.baseUrl
  /// 3. 重建 Dio 实例（保留所有拦截器，仅替换 baseUrl）
  /// 4. 清空本地 DB 缓存（categories / videos）— 旧数据来自旧源站，避免误用
  /// 5. 主动调用 HomeController.refresh() — 强制刷新首页
  ///    （用户切换镜像后通常立即切回首页查看效果，需要新数据立即生效）
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

    // 4. 清空本地缓存（categories + videos）
    //
    // 旧缓存来自旧源站，可能存在以下问题：
    // - 封面图 data-original 是相对路径（在新源站下可用，但旧源站可能已死）
    // - 旧源站若已变跳转壳，缓存的分类列表虽仍可用但视频项可能是空列表
    // - 用户主动切换镜像的诉求通常是"当前源站有问题"，清空更符合直觉
    try {
      if (Get.isRegistered<AppDatabase>()) {
        final db = Get.find<AppDatabase>();
        await db.categoryDao.deleteAll();
        await db.videoDao.deleteAll();
      }
    } catch (_) {
      // 清缓存失败不阻断切换流程
    }

    // 5. 主动刷新首页（异步触发，不阻塞切换流程）
    //
    // 使用 Get.isRegistered 防御性检查，避免在启动早期 / 测试环境报错。
    // 刷新采用 forceRefresh=true，绕过缓存直接拉取新源站数据。
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refresh();
      }
      // 收藏夹中的视频项 coverUrl 是绝对路径（来自旧源站），切换后也刷新一下
      if (Get.isRegistered<FavoritesController>()) {
        Get.find<FavoritesController>().loadFavorites();
      }
      // 历史记录同样
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().loadHistory();
      }
    } catch (_) {
      // 刷新失败不阻断切换流程
    }

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

  /// 简单连通性测试（GET 请求并验证返回内容是真实 macCMS 站点）
  ///
  /// 返回 null 表示成功，否则返回错误信息。
  ///
  /// **重要**：跳转壳对 HEAD/GET 都返回 200 OK，但 GET 拿到的是 JS 跳转脚本
  /// （不到 1KB，无 macCMS HTML 结构）。仅靠 HTTP 状态码无法区分真实源站和跳转壳，
  /// 必须验证响应体包含 macCMS 标志（如 `.stui-vodlist__box` 或 `.stui-pannel__menu`）。
  static Future<String?> testConnectivity(String baseUrl) async {
    try {
      final testDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          followRedirects: true,
          // 跳转壳也返回 200，validateStatus 必须放宽到所有状态码都通过
          // （让响应体进入下面的内容校验逻辑）
          validateStatus: (s) => s != null,
          responseType: ResponseType.plain,
        ),
      );
      final resp = await testDio.get<String>('/');
      testDio.close();

      final html = resp.data ?? '';
      // 真实源站首页必含 macCMS 标志性 class（任一命中即视为真实源站）
      const realSiteMarkers = [
        'stui-vodlist__box',
        'stui-pannel__menu',
        'stui-header__menu',
      ];
      final isRealSite = realSiteMarkers.any((m) => html.contains(m));
      if (!isRealSite) {
        // 跳转壳特征：含 hao123 / location.href / script type="text/javascript"
        if (html.contains('hao123') ||
            html.contains('location.href') ||
            html.length < 1000) {
          return '该地址是跳转壳，非真实源站';
        }
        return '响应内容不是 macCMS 站点（缺少 stui 标志）';
      }
      return null;
    } on DioException catch (e) {
      return e.message ?? e.type.name;
    } catch (e) {
      return e.toString();
    }
  }
}
