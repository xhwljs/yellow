import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/network/dio_client.dart';
import 'package:yellow_depot/data/database/app_database.dart';
import 'package:yellow_depot/presentation/controllers/favorites_controller.dart';
import 'package:yellow_depot/presentation/controllers/history_controller.dart';
import 'package:yellow_depot/presentation/controllers/home_controller.dart';

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
  ///
  /// **注意**：即便用户持久化了跳转壳地址，[testConnectivity] 也能通过
  /// 跳转壳自动迁移机制找到最新真实地址并切换，所以这里只列硬性死链。
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
  ///
  /// **跳转壳自动迁移**（2026-07-20 新增）：即便用户持久化的不在 [_deadMirrors]
  /// 列表里，启动时也会异步触发健康检查，若发现是跳转壳则自动通过跳转服务
  /// （cktongji.com:8899 / hk234.space:8899）解析到最新真实地址并切换。
  /// 例如：持久化 http://555973.xyz → 启动时检测到是跳转壳 → 自动迁移到 http://555980.xyz。
  ///
  /// **不阻塞启动**：异步触发，App 立即进入主界面，迁移完成后 Dio 重建并刷新首页。
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyApiBaseUrl);
    if (saved == null || saved.isEmpty) {
      // 未保存任何 baseUrl → 异步健康检查默认 baseUrl
      _scheduleStartupHealthCheck();
      return;
    }

    // 自动迁移死链（已知失效镜像）
    if (_deadMirrors.contains(saved)) {
      await prefs.setString(
        AppConstants.keyApiBaseUrl,
        AppConstants.defaultBaseUrl,
      );
      AppConstants.baseUrl = AppConstants.defaultBaseUrl;
      _scheduleStartupHealthCheck();
      return;
    }

    AppConstants.baseUrl = saved;
    // 异步触发跳转壳自动迁移（不阻塞启动）
    _scheduleStartupHealthCheck();
  }

  /// 启动时异步健康检查：检测当前 baseUrl 是否是跳转壳，是则自动迁移
  ///
  /// **重要**：App 启动时用户可能持久化了已变跳转壳的旧地址（如 555973.xyz），
  /// 但 [_deadMirrors] 列表无法穷举所有变壳地址。这里通过实际请求首页检测，
  /// 发现跳转壳则自动迁移到最新真实地址（如 555980.xyz），并重建 Dio、刷新首页。
  ///
  /// 不阻塞启动流程：用 Future.microtask 异步触发，App 立即进入主界面。
  /// 用户在首页 Loading 状态下等待 1-3 秒后自动刷新出新内容。
  static void _scheduleStartupHealthCheck() {
    Future.microtask(() async {
      try {
        final current = AppConstants.baseUrl;
        // 健康检查：如果当前 baseUrl 是跳转壳，testConnectivity 会自动迁移
        // 并持久化新地址 + 重建 Dio + 刷新首页
        final result = await testConnectivity(current);
        if (result == null) {
          // 健康检查通过（可能已迁移，可能本来就是真实源站）
        } else {
          // 健康检查失败（非跳转壳，可能是网络错误）— 不主动切换，避免误伤
        }
      } catch (_) {
        // 健康检查失败不影响启动流程
      }
    });
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
  /// **跳转壳自动迁移机制**（2026-07-20 修订）：
  /// 源站 555973.xyz 等老入口实际是"跳转壳"——返回 200 + JS 跳转脚本：
  /// ```html
  /// <a href="" id="hao123"></a>
  /// <script>var strU = "https://cktongji.com:8899/?u=...&p=..."; hao123.href = strU; ...click...</script>
  /// ```
  /// 跳转服务（cktongji.com:8899 / hk234.space:8899 是同服务不同域名）返回
  /// **HTTP 302 Location** 指向最新真实地址（如 555980.xyz）。
  /// 运营方每次被封就更新 302 的 Location，相当于"动态域名解析"。
  ///
  /// Dio 不会执行 JS，所以拿到 425 字节 HTML 就停了，被旧代码误判为跳转壳。
  /// 现在改为：
  /// 1. 检测到跳转壳模式（含 strU + hao123）→ 提取 strU URL
  /// 2. 请求 strU → 读取 302 Location header
  /// 3. 用 Location 作为新 baseUrl，重新请求首页
  /// 4. 新地址通过 macCMS 标志检测 → 调用 [switchTo] 持久化并切换 → 返回 null（成功）
  /// 5. 新地址仍失败 → 返回错误信息
  ///
  /// 调用方应在测试完成后重新读取 [current] 显示当前地址（若发生自动迁移会显示新地址）。
  static Future<String?> testConnectivity(String baseUrl) async {
    final html = await _fetchHomepage(baseUrl);
    if (html == null) {
      return '无法访问 $baseUrl（网络错误或超时）';
    }

    // 1) 命中 macCMS 标志 → 真实源站，直接通过
    if (_hasMacCmsMarker(html)) return null;

    // 2) 检测跳转壳 → 尝试自动迁移到最新真实地址
    if (_isRedirectShell(html)) {
      final migratedUrl = await _tryMigrateFromRedirectShell(html);
      if (migratedUrl == null) {
        return '跳转壳中未找到跳转服务 URL，无法自动迁移';
      }
      // 用新地址重新请求首页（不递归触发迁移，避免死循环）
      final newHtml = await _fetchHomepage(migratedUrl);
      if (newHtml == null) {
        return '跳转服务指向的新地址无法访问：$migratedUrl';
      }
      if (_hasMacCmsMarker(newHtml)) {
        // 新地址是真实源站 → 持久化并切换
        await switchTo(migratedUrl);
        return null; // 成功（已自动迁移）
      }
      return '跳转服务指向的新地址不是 macCMS 站点：$migratedUrl';
    }

    // 3) 既无 macCMS 标志也无跳转壳特征 → 视为通过（可能是新模板，不阻断用户）
    return null;
  }

  /// 请求 baseUrl 首页并返回 HTML 字符串
  ///
  /// 失败（网络错误/超时）返回 null。
  static Future<String?> _fetchHomepage(String baseUrl) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        followRedirects: true,
        // 跳转壳也返回 200，validateStatus 必须放宽到所有状态码都通过
        validateStatus: (s) => s != null,
        responseType: ResponseType.plain,
        headers: {
          // 模拟移动浏览器 UA，避免源站对默认 Dio UA 反爬返回错误内容
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ),
    );
    try {
      final resp = await dio.get<String>('/');
      return resp.data ?? '';
    } catch (_) {
      return null;
    } finally {
      dio.close();
    }
  }

  /// 检测 HTML 是否包含 macCMS 标志（任一命中即视为真实源站）
  ///
  /// 涵盖主流模板：stui / module / myui / 默认 + 通用 vodlist
  static bool _hasMacCmsMarker(String html) {
    const realSiteMarkers = [
      // stui 模板
      'stui-vodlist__box',
      'stui-pannel__menu',
      'stui-header__menu',
      'stui-page__item',
      // module 模板
      'module-vodlist__box',
      'module-page-info',
      'module-items',
      // myui 模板
      'myui-vodlist__box',
      'myui-page-info',
      'myui-content__list',
      // 默认 / 通用 macCMS 标志
      'class="vodlist',
      'vodlist__box',
      'mac_vod',
      'maccms',
      '/index.php/art/',
      '/index.php/vod/',
      '/api.php/provide',
    ];
    return realSiteMarkers.any((m) => html.contains(m));
  }

  /// 检测 HTML 是否是跳转壳
  ///
  /// 跳转壳特征（实测 555973.xyz 等）：
  /// - 内容简短（< 3KB）
  /// - 含 `<a id="hao123">` 锚点
  /// - 含 `var strU = "..."` 跳转服务 URL（如 cktongji.com:8899 / hk234.space:8899）
  /// - JS 模拟点击 hao123 锚点触发跳转
  static bool _isRedirectShell(String html) {
    if (html.length > 3000) return false;
    if (!html.contains('hao123')) return false;
    // 必须含 strU 变量赋值（跳转服务 URL）
    return RegExp(r'''var\s+strU\s*=\s*["']''').hasMatch(html);
  }

  /// 从跳转壳 HTML 中提取跳转服务 URL 并请求，返回 302 Location（最新真实地址）
  ///
  /// 跳转壳 JS 形如：
  /// ```js
  /// var strU = "https://cktongji.com:8899/?u=http://555973.xyz/&p=/";
  /// ```
  /// 请求 strU → 服务器返回 302 Found + Location: http://555980.xyz
  ///
  /// 返回值：
  /// - 成功：Location URL（最新真实地址）
  /// - 失败：null
  static Future<String?> _tryMigrateFromRedirectShell(String html) async {
    // 1. 提取 var strU = "..." 中的 URL
    final regex = RegExp(r'''var\s+strU\s*=\s*["']([^"']+)["']''');
    final match = regex.firstMatch(html);
    if (match == null) return null;
    final redirectServiceUrl = match.group(1);
    if (redirectServiceUrl == null || redirectServiceUrl.isEmpty) return null;

    // 2. 请求跳转服务，禁用 followRedirects 拿到原始 302 响应
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        followRedirects: false, // 不自动跟随，拿原始 302
        validateStatus: (s) => s != null, // 接受所有状态码
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ),
    );
    try {
      final resp = await dio.get<String>(redirectServiceUrl);
      // 302 响应的 Location header 指向最新真实地址
      final location = resp.headers.value('location');
      if (location != null && location.isNotEmpty) {
        return location;
      }
      // 某些跳转服务可能返回 200 + JS 跳转，尝试从 body 提取
      final body = resp.data ?? '';
      final jsMatch = RegExp(
        r'''(?:location\.href|window\.location\.replace)\s*=\s*["']([^"']+)["']''',
      ).firstMatch(body);
      return jsMatch?.group(1);
    } catch (_) {
      return null;
    } finally {
      dio.close();
    }
  }
}
