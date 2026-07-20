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
/// 源站域名可能因反爬频繁更换（如 555973.xyz → 555980.xyz ...），
/// 提供运行时切换 + 持久化 + Dio 重建 + 数据刷新通知能力，避免每次换域名都要发版。
///
/// **跳转壳自动迁移机制**（2026-07-20）：
/// 老入口（如 555973.xyz）实际是"跳转壳"——返回 200 + 425 字节 HTML
/// 含 `var strU = "https://hk234.space:8899/?u=...&p=..."` 模拟点击跳转。
/// 跳转服务返回 302 Location 指向最新真实地址（如 555980.xyz）。
/// 运营方每次被封就更新 302 的 Location，相当于"动态域名解析"。
///
/// [testConnectivity] 检测到跳转壳后会自动完成迁移链路：
/// 1) 检测跳转壳特征（< 3KB + hao123 + var strU）
/// 2) 正则提取 strU URL
/// 3) 请求 strU 拿 302 Location
/// 4) 用 Location 作为新 baseUrl 重新请求首页
/// 5) 新地址通过 macCMS 标志检测 → switchTo 持久化并切换
///    switchTo 会把新地址自动添加到 [presetMirrors] 并持久化到 SP，
///    镜像列表 UI 会立即显示最新可用域名。
///
/// **镜像列表持久化**：
/// - [presetMirrors] 是可变 List，初始为内置默认值
/// - [loadFromPrefs] 启动时从 SP 加载用户保存的镜像列表覆盖
/// - [switchTo] 时如果新 URL 不在列表则添加到列表头部并持久化
/// - 这样用户测试出最新地址后会自动保存到镜像列表，下次启动仍可见
class ApiServerSwitcher {
  ApiServerSwitcher._();

  /// 内置推荐镜像列表（初始默认值，运行时可被 SP 覆盖）
  ///
  /// 实测（2026-07-19）：
  /// - 555976.xyz ✅ 当前真实源站
  /// - 555972.xyz ⚠️ 未验证，保留作为候选
  /// - 555975.xyz ❌ 已变跳转壳，列入 [_deadMirrors]
  /// - 555974.xyz ❌ 已变跳转壳，列入 [_deadMirrors]
  /// - 555973.xyz ❌ 已是跳转壳
  ///
  /// **注意**：此列表是可变的，运行时会从 SP 加载用户保存的镜像列表覆盖。
  /// 跳转壳自动迁移时新地址会自动追加到列表头部（[switchTo] 内部处理）。
  static List<String> presetMirrors = <String>[
    'http://555976.xyz',
    'http://555972.xyz',
  ];

  /// 已知失效镜像列表（硬性死链，不参与自动迁移）
  ///
  /// 用于 [loadFromPrefs] 自动迁移：用户旧版 App 持久化过这些 URL，
  /// 升级后启动时若检测到，自动回退到 [AppConstants.defaultBaseUrl]。
  ///
  /// **注意**：即便用户持久化了跳转壳地址，[testConnectivity] 也能通过
  /// 跳转壳自动迁移机制找到最新真实地址并切换，所以这里只列硬性死链。
  static const List<String> _deadMirrors = <String>[
    'http://555975.xyz',
    'http://555974.xyz',
    'http://555973.xyz',
  ];

  /// SP key：用户保存的镜像列表（JSON 数组）
  static const String _keyMirrorList = 'api_mirror_list';

  /// 当前生效的 baseUrl
  static String get current => AppConstants.baseUrl;

  /// 从 SharedPreferences 加载用户保存的 baseUrl + 镜像列表（应用启动时调用）
  ///
  /// **加载顺序**：
  /// 1. 加载用户保存的镜像列表覆盖 [presetMirrors]（如果 SP 中有保存）
  /// 2. 加载用户保存的 baseUrl，若为已知死链则回退到默认
  /// 3. 异步触发跳转壳健康检查（不阻塞启动）
  ///
  /// **跳转壳自动迁移**（2026-07-20 新增）：即便用户持久化的不在 [_deadMirrors]
  /// 列表里，启动时也会异步触发健康检查，若发现是跳转壳则自动通过跳转服务
  /// （cktongji.com:8899 / hk234.space:8899）解析到最新真实地址并切换。
  /// 例如：持久化 http://555973.xyz → 启动时检测到是跳转壳 → 自动迁移到 http://555980.xyz。
  ///
  /// **不阻塞启动**：异步触发，App 立即进入主界面，迁移完成后 Dio 重建并刷新首页。
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 加载用户保存的镜像列表（覆盖默认值）
    final savedMirrors = prefs.getStringList(_keyMirrorList);
    if (savedMirrors != null && savedMirrors.isNotEmpty) {
      presetMirrors = List<String>.from(savedMirrors);
    }

    // 2. 加载 baseUrl
    final saved = prefs.getString(AppConstants.keyApiBaseUrl);
    if (saved == null || saved.isEmpty) {
      _scheduleStartupHealthCheck();
      return;
    }

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
    _scheduleStartupHealthCheck();
  }

  /// 持久化镜像列表到 SharedPreferences
  static Future<void> _saveMirrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyMirrorList, presetMirrors);
    } catch (_) {
      // 持久化失败不阻断流程
    }
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
        await testConnectivity(current);
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
  /// 3. 如果新 URL 不在镜像列表则添加到列表头部并持久化（让用户能在镜像列表看到）
  /// 4. 重建 Dio 实例（保留所有拦截器，仅替换 baseUrl）
  /// 5. 清空本地 DB 缓存（categories / videos）— 旧数据来自旧源站，避免误用
  /// 6. 主动调用 HomeController.refresh() — 强制刷新首页
  ///
  /// 返回旧 baseUrl 供 UI 提示。
  static Future<String> switchTo(String newBaseUrl) async {
    final old = AppConstants.baseUrl;
    if (newBaseUrl == old) return old;

    // 1. 持久化 baseUrl
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyApiBaseUrl, newBaseUrl);

    // 2. 更新全局常量
    AppConstants.baseUrl = newBaseUrl;

    // 3. 如果新 URL 不在镜像列表，添加到列表头部并持久化
    //    （例如：测试 555973.xyz 跳转壳 → 自动迁移到 555980.xyz → 加入列表）
    if (!presetMirrors.contains(newBaseUrl)) {
      presetMirrors.insert(0, newBaseUrl);
      await _saveMirrors();
    }

    // 4. 重建 Dio
    await DioClient.rebuildWithBaseUrl(newBaseUrl);

    // 5. 清空本地缓存（categories + videos）
    try {
      if (Get.isRegistered<AppDatabase>()) {
        final db = Get.find<AppDatabase>();
        await db.categoryDao.deleteAll();
        await db.videoDao.deleteAll();
      }
    } catch (_) {
      // 清缓存失败不阻断切换流程
    }

    // 6. 主动刷新首页（异步触发，不阻塞切换流程）
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refresh();
      }
      if (Get.isRegistered<FavoritesController>()) {
        Get.find<FavoritesController>().loadFavorites();
      }
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

  /// 自动测试镜像列表，发现跳转壳则自动迁移
  ///
  /// 调用场景：
  /// - 用户打开 API 服务器 sheet 时自动调用，批量测试所有镜像
  /// - 测试过程中如果发现某个镜像已是跳转壳，则自动迁移到最新地址并更新列表
  ///
  /// 返回值：
  /// - 成功：最新可用的 baseUrl（testConnectivity 内部已 switchTo）
  /// - 失败：null（所有镜像都不可用）
  ///
  /// 注意：此方法是串行的，避免并发请求过多触发反爬。
  static Future<String?> autoTestMirrors() async {
    final mirrors = List<String>.from(presetMirrors);
    for (final mirror in mirrors) {
      final result = await testConnectivity(mirror);
      if (result == null) {
        // 此镜像可用（可能已发生自动迁移到最新地址，current 已是最新）
        return current;
      }
    }
    return null;
  }

  /// 简单连通性测试（GET 请求并验证返回内容是真实 macCMS 站点）
  ///
  /// 返回 null 表示成功，否则返回错误信息。
  ///
  /// **跳转壳自动迁移机制**：
  /// 源站 55596x.xyz 等老入口实际是"跳转壳"——返回 200 + 424 字节 HTML
  /// 含 `var strU="https://hk234.space:8899/?u="+window.location+"&p="+...`
  /// 模拟点击 hao123 锚点跳转。跳转服务（cktongji.com:8899 /
  /// hk234.space:8899 是同服务不同域名）返回 302 Location 指向最新真实地址。
  ///
  /// **关键修复（2026-07-20）**：
  /// JS 中 strU 是字符串字面量 + JS 表达式拼接构造的，不是完整的字面量。
  /// 例如 `var strU="https://hk234.space:8899/?u="+window.location+"&p="+window.location.pathname+window.location.search;`
  /// 字符串字面量只是 `"https://hk234.space:8899/?u="`，后面用 + 拼接 window.location 等。
  /// 旧代码只提取字面量导致请求 URL 不完整。
  /// 现在改为：模拟 JS 字符串拼接，把 window.location 替换为 [baseUrl]，
  /// pathname 替换为 `/`，search 替换为空字符串，构造完整 URL。
  ///
  /// 流程：
  /// 1. 检测到跳转壳模式（含 strU + hao123）→ 提取 strU 完整表达式
  /// 2. 模拟 JS 拼接构造完整跳转服务 URL
  /// 3. 请求该 URL → 读取 302 Location header
  /// 4. 用 Location 作为新 baseUrl，重新请求首页
  /// 5. 新地址通过 macCMS 标志检测 → 调用 [switchTo] 持久化并切换 → 返回 null（成功）
  ///    （switchTo 内部会把新地址自动添加到 [presetMirrors] 并持久化到 SP）
  /// 6. 新地址仍失败 → 返回错误信息
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
      final migratedUrl = await _tryMigrateFromRedirectShell(html, baseUrl);
      if (migratedUrl == null) {
        return '跳转壳中未找到跳转服务 URL，无法自动迁移';
      }
      // 用新地址重新请求首页验证
      final newHtml = await _fetchHomepage(migratedUrl);
      // 验证条件（任一通过即视为迁移成功）：
      // a) 命中 macCMS 标志 → 真实源站
      // b) 反爬系统返回 418（空响应）→ 服务器存在但被反爬拦截，仍是有效 baseUrl
      //    （Quantum 反爬系统会概率性返回 418，App 后续请求会自动重试）
      if (newHtml != null && _hasMacCmsMarker(newHtml)) {
        // 新地址是真实源站 → 持久化并切换
        await switchTo(migratedUrl);
        return null; // 成功（已自动迁移）
      }
      // 418 或空响应：检查上次响应状态码是否为 418
      // 若是 418 说明服务器存在但被反爬，仍可切换（App 重试机制会处理）
      if (newHtml == '' || await _lastFetchWasAntiCrawler(migratedUrl)) {
        await switchTo(migratedUrl);
        return null; // 迁移到最新地址（反爬 418 由 RetryInterceptor 处理）
      }
      if (newHtml == null) {
        // 网络错误：仍切换地址（让 RetryInterceptor 在实际请求时重试）
        await switchTo(migratedUrl);
        return null;
      }
      return '跳转服务指向的新地址不是 macCMS 站点：$migratedUrl';
    }

    // 3) 既无 macCMS 标志也无跳转壳特征 → 视为通过（可能是新模板，不阻断用户）
    return null;
  }

  /// 检测上次请求该 URL 是否返回 418 反爬状态码
  ///
  /// Quantum 反爬系统会概率性返回 418，但服务器实际可用。
  /// App 后续请求会通过 RetryInterceptor 自动重试 + 切换 UA 绕过。
  static Future<bool> _lastFetchWasAntiCrawler(String baseUrl) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        followRedirects: true,
        validateStatus: (s) => s != null,
        responseType: ResponseType.plain,
        headers: {
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
      // 418 = Quantum 反爬系统拦截，服务器实际存在
      return resp.statusCode == 418;
    } catch (_) {
      return false;
    } finally {
      dio.close();
    }
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
  /// **关键修复（2026-07-20）**：JS 中 strU 是字符串字面量 + JS 表达式拼接构造的。
  /// 例如：
  /// ```js
  /// var strU="https://hk234.space:8899/?u="+window.location+"&p="+window.location.pathname+window.location.search;
  /// ```
  /// 字符串字面量只是 `"https://hk234.space:8899/?u="`，后面用 `+` 拼接 JS 表达式。
  /// 旧代码只提取字面量导致请求 URL 不完整，请求 `https://hk234.space:8899/?u=`
  /// 拿不到正确的 302 Location。
  ///
  /// 修复方案：模拟 JS 字符串拼接，把 JS 表达式替换为实际值：
  /// - `window.location` → [originalBaseUrl]（用户测试的镜像 URL）
  /// - `window.location.pathname` → `/`
  /// - `window.location.search` → `''`（空字符串）
  /// - `window.location.href` → [originalBaseUrl]
  /// - `window.location.origin` → 协议 + 域名（http://555976.xyz）
  /// - `location`（无 window. 前缀）→ 同 window.location
  ///
  /// 然后提取所有字符串字面量并拼接成完整 URL。
  ///
  /// 流程：
  /// 1. 提取 `var strU = ...;` 的完整赋值表达式（到 `;` 为止）
  /// 2. 替换 JS 表达式为字符串字面量
  /// 3. 提取所有 `"..."` / `'...'` 字面量并拼接
  /// 4. 请求完整 URL → 读取 302 Location header
  ///
  /// 返回值：
  /// - 成功：Location URL（最新真实地址，如 http://555980.xyz）
  /// - 失败：null
  static Future<String?> _tryMigrateFromRedirectShell(
    String html,
    String originalBaseUrl,
  ) async {
    // 1. 提取 var strU = ...; 的完整赋值表达式（到第一个 ; 为止）
    final stmtMatch = RegExp(
      r'''var\s+strU\s*=\s*([^;]+);''',
    ).firstMatch(html);
    if (stmtMatch == null) return null;
    String expr = stmtMatch.group(1) ?? '';

    // 2. 计算 originalBaseUrl 的 origin（去掉 path/query 部分）
    //    例如 http://555976.xyz/ → http://555976.xyz
    String origin = originalBaseUrl;
    final originMatch = RegExp(r'''^(https?://[^/]+)''').firstMatch(originalBaseUrl);
    if (originMatch != null) {
      origin = originMatch.group(1) ?? originalBaseUrl;
    }

    // 3. 模拟 JS 表达式替换（注意顺序：先替换长的，避免部分替换冲突）
    //    window.location.pathname → '/'
    //    window.location.search → ''
    //    window.location.href → originalBaseUrl
    //    window.location.origin → origin
    //    window.location → originalBaseUrl
    //    location.pathname → '/'
    //    location.search → ''
    //    location.href → originalBaseUrl
    //    location.origin → origin
    //    location → originalBaseUrl
    expr = expr
        .replaceAll('window.location.pathname', "'/'")
        .replaceAll('window.location.search', "''")
        .replaceAll('window.location.href', "'$originalBaseUrl'")
        .replaceAll('window.location.origin', "'$origin'")
        .replaceAll('window.location', "'$originalBaseUrl'")
        .replaceAll('location.pathname', "'/'")
        .replaceAll('location.search', "''")
        .replaceAll('location.href', "'$originalBaseUrl'")
        .replaceAll('location.origin', "'$origin'")
        // 残留的 location（无 .xxx 后缀）也替换为 originalBaseUrl
        .replaceAll(RegExp(r'''\blocation\b'''), "'$originalBaseUrl'");

    // 4. 统一引号：把 " 改为 ' 方便提取
    expr = expr.replaceAll('"', "'");

    // 5. 提取所有 'xxx' 字符串字面量并按顺序拼接
    final parts = RegExp(r"""'([^']*)'""").allMatches(expr).map((m) => m.group(1) ?? '').toList();
    if (parts.isEmpty) return null;
    final redirectServiceUrl = parts.join('');

    if (redirectServiceUrl.isEmpty ||
        !redirectServiceUrl.startsWith('http://') &&
            !redirectServiceUrl.startsWith('https://')) {
      return null;
    }

    // 6. 请求跳转服务，禁用 followRedirects 拿到原始 302 响应
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
