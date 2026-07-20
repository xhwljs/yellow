import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/utils/logger.dart';

/// GitHub Release 信息
class GitHubRelease {
  /// release tag，如 "v1.0.1"
  final String tagName;

  /// release 标题
  final String name;

  /// release body（markdown）
  final String body;

  /// APK 下载 URL（来自 assets[].browser_download_url）
  final String apkDownloadUrl;

  /// APK 文件名（如 app-arm64-v8a-debug.apk）
  final String apkFileName;

  /// 创建时间
  final DateTime publishedAt;

  /// 是否为预发布版本
  final bool prerelease;

  /// 是否为强制更新版本
  ///
  /// 解析规则：[GitHubReleaseService._kForceUpdateMarker] 标记出现在
  /// release body 中即为强制更新（如 "[强制更新]" 或 "[force-update]"）。
  /// 强制更新 → UpdateDialog 只显示"立即更新"按钮
  /// 非强制更新 → UpdateDialog 显示"立即更新" + "稍后"按钮
  final bool forceUpdate;

  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.apkDownloadUrl,
    required this.apkFileName,
    required this.publishedAt,
    required this.prerelease,
    required this.forceUpdate,
  });

  /// 比较版本号，返回 true 表示当前版本低于 release 版本（需要更新）
  ///
  /// 解析规则：
  /// - tag 形如 "v1.0.1" 或 "1.0.1"，去掉 'v' 前缀
  /// - 按 "." 分割，逐段比较数字
  /// - 不足的段视为 0（如 1.0 < 1.0.1）
  bool isNewerThan(String currentVersion) {
    final releaseVersion = tagName.toLowerCase().startsWith('v')
        ? tagName.substring(1)
        : tagName;
    return _compareVersions(releaseVersion, currentVersion) > 0;
  }

  /// 版本号比较：返回 1 表示 a > b，-1 表示 a < b，0 表示相等
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  }
}

/// GitHub Releases 服务
///
/// 调用 GitHub REST API 检查仓库的最新 release，并解析出 APK 下载链接。
///
/// API: GET https://api.github.com/repos/{owner}/{repo}/releases/latest
/// 返回 JSON：
/// ```json
/// {
///   "tag_name": "v1.0.1",
///   "name": "Release v1.0.1",
///   "body": "## 更新内容...",
///   "prerelease": false,
///   "published_at": "2026-07-20T12:00:00Z",
///   "assets": [
///     {
///       "name": "app-arm64-v8a-debug.apk",
///       "browser_download_url": "https://github.com/.../app-arm64-v8a-debug.apk"
///     }
///   ]
/// }
/// ```
class GitHubReleaseService {
  /// GitHub 仓库信息（owner/repo）
  ///
  /// 来自 git remote: https://github.com/xhwljs/yellow.git
  static const String repoOwner = 'xhwljs';
  static const String repoName = 'yellow';

  /// GitHub API 根 URL
  static const String apiBaseUrl = 'https://api.github.com';

  /// APK asset 名后缀匹配（CI 构建产物：app-arm64-v8a-debug.apk）
  static const String apkAssetNamePattern = '.apk';

  /// 强制更新标记列表
  ///
  /// 写在 release body 中即视为强制更新。
  /// CI auto-release 默认会在 body 中加入 "[强制更新]" 标记；
  /// 开发者手动发 release 时可选择是否加入此标记。
  static const List<String> _kForceUpdateMarkers = [
    '[强制更新]',
    '[force-update]',
    '[FORCE-UPDATE]',
  ];

  /// 判断 release body 是否包含强制更新标记
  static bool _hasForceUpdateMarker(String body) {
    if (body.isEmpty) return false;
    for (final marker in _kForceUpdateMarkers) {
      if (body.contains(marker)) return true;
    }
    return false;
  }

  /// 获取最新 release（不含预发布版本）
  ///
  /// 调用 GitHub API 的 /releases/latest 端点。
  /// 失败抛 DioException 或自定义异常。
  ///
  /// 返回 null 表示无可用 release（仓库没有任何 release）。
  static Future<GitHubRelease?> getLatestRelease() async {
    final url = '$apiBaseUrl/repos/$repoOwner/$repoName/releases/latest';
    appLogger.i('检查 GitHub 最新 release: $url');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'YellowDepot-Update-Checker/1.0',
      },
    ));

    try {
      final response = await dio.get<dynamic>(url);
      final data = response.data as Map<String, dynamic>;

      final tagName = data['tag_name'] as String? ?? '';
      if (tagName.isEmpty) {
        appLogger.w('release 缺少 tag_name 字段');
        return null;
      }

      // 找到 .apk asset
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      String? apkName;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith(apkAssetNamePattern)) {
          apkUrl = asset['browser_download_url'] as String?;
          apkName = name;
          break;
        }
      }

      if (apkUrl == null || apkUrl.isEmpty) {
        appLogger.w('release 中无 .apk 文件，跳过更新检查');
        return null;
      }

      final publishedAtStr = data['published_at'] as String? ?? '';
      DateTime? publishedAt;
      if (publishedAtStr.isNotEmpty) {
        publishedAt = DateTime.tryParse(publishedAtStr);
      }

      final body = data['body'] as String? ?? '';
      final forceUpdate = _hasForceUpdateMarker(body);

      return GitHubRelease(
        tagName: tagName,
        name: data['name'] as String? ?? tagName,
        body: body,
        apkDownloadUrl: apkUrl,
        apkFileName: apkName ?? 'update.apk',
        publishedAt: publishedAt ?? DateTime.now(),
        prerelease: data['prerelease'] as bool? ?? false,
        forceUpdate: forceUpdate,
      );
    } on DioException catch (e) {
      // 404 表示仓库无 release（GitHub 返回 404）
      if (e.response?.statusCode == 404) {
        appLogger.i('GitHub 仓库无 release（404）');
        return null;
      }
      appLogger.w('GitHub API 请求失败: ${e.message}');
      rethrow;
    } finally {
      dio.close();
    }
  }

  /// 检查是否有新版本可用
  ///
  /// 流程：
  /// 1. 调用 GitHub API 拿最新 release
  /// 2. 跳过预发布版本
  /// 3. 比较 release.tagName 与 [AppConstants.appVersion]
  ///    - 相同 → 已是最新版本，返回 null
  ///    - release.tagName 更大 → 缓存到 SharedPreferences 后返回 release
  /// 4. 任何步骤失败（网络问题/限流）→ 从 SharedPreferences 读取缓存的 release
  ///
  /// **缓存机制（修复"更新中途被强杀后再次启动不弹对话框"问题）**：
  /// - 之前实现：仅依赖 GitHub API 实时调用，网络失败则 update=null，直接进入 App
  /// - 用户场景：开始更新下载后强杀 App，重启时网络抖动 / API 限流导致 checkForUpdate
  ///   抛异常 → update=null → 跳过更新对话框 → 直接进入旧版本 App
  /// - 现在：发现新版本时持久化到 SP；启动时 API 失败则从 SP 恢复，确保
  ///   即便网络抖动也能正确弹出更新对话框
  ///
  /// 版本号来源说明：
  /// [AppConstants.appVersion] 由 CI 在构建 APK 时注入：
  /// - CI 在 push 到 main 时计算 tag（v{YYYY.MMDD.N}），
  ///   用 sed 把 tag（去掉 v 前缀）写入 lib/core/constants/app_constants.dart
  ///   的 appVersion 字段
  /// - 因此用户安装的 APK 内部 appVersion 已经是该 release 对应的版本号
  /// - 启动时比较 AppConstants.appVersion 与 latest release.tagName（去掉 v）
  /// - 相同 → 跳过更新；不同（latest 更大）→ 触发更新
  ///
  /// 返回 GitHubRelease 表示有新版本（含 APK 下载链接），否则返回 null。
  /// 不抛异常（内部捕获，失败时尝试用缓存，再失败返回 null 让调用方静默跳过更新流程）。
  static Future<GitHubRelease?> checkForUpdate() async {
    try {
      final release = await getLatestRelease();
      if (release == null) {
        // GitHub 上无 release（仓库新/被删）→ 尝试用缓存
        appLogger.i('GitHub API 返回无 release，尝试读取缓存的 release 信息');
        return _checkCachedRelease();
      }

      // 跳过预发布版本
      if (release.prerelease) {
        appLogger.i('最新 release 是预发布版本 ${release.tagName}，跳过');
        return _checkCachedRelease();
      }

      // 版本比较：release.tagName（去掉 v 前缀）vs AppConstants.appVersion
      final hasNewVersion = release.isNewerThan(AppConstants.appVersion);
      if (hasNewVersion) {
        // 发现新版本 → 缓存到 SharedPreferences
        // 这样即使下次启动时 GitHub API 失败也能用缓存的 release 触发更新
        await _cacheRelease(release);
        appLogger.i(
          '发现新版本：${release.tagName}（当前 ${AppConstants.appVersion}，'
          '强制更新: ${release.forceUpdate}）',
        );
        return release;
      }

      // 当前已是最新版本 → 不需要更新，清空过期缓存（避免下次启动误弹）
      appLogger.i(
        '当前已是最新版本 (app: ${AppConstants.appVersion} ≥ release: ${release.tagName})',
      );
      await _clearCachedRelease();
      return null;
    } catch (e) {
      // GitHub API 调用失败 → 尝试用缓存的 release 信息
      appLogger.w('检查更新失败: $e，尝试读取缓存的 release 信息');
      return _checkCachedRelease();
    }
  }

  /// 把最新 release 信息持久化到 SharedPreferences
  ///
  /// 仅在发现新版本（release.tagName > 当前版本）时调用。
  /// 用户安装新版本后 appVersion 会与 release.tagName 相同或更高，
  /// [_checkCachedRelease] 中比较返回 false → 不弹对话框。
  static Future<void> _cacheRelease(GitHubRelease release) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode({
        'tagName': release.tagName,
        'name': release.name,
        'body': release.body,
        'apkDownloadUrl': release.apkDownloadUrl,
        'apkFileName': release.apkFileName,
        'publishedAt': release.publishedAt.millisecondsSinceEpoch,
        'prerelease': release.prerelease,
        'forceUpdate': release.forceUpdate,
      });
      await prefs.setString(AppConstants.keyCachedReleaseInfo, json);
      appLogger.i('已缓存最新 release 信息: ${release.tagName}');
    } catch (e) {
      appLogger.w('缓存 release 失败: $e');
    }
  }

  /// 清空过期的缓存 release 信息（当前已是最新版本时调用）
  static Future<void> _clearCachedRelease() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyCachedReleaseInfo);
      appLogger.i('已清空缓存的 release 信息（当前已是最新版本）');
    } catch (e) {
      appLogger.w('清空缓存 release 失败: $e');
    }
  }

  /// 从 SharedPreferences 读取缓存的 release，并检查是否仍需更新
  ///
  /// 使用场景：GitHub API 调用失败（网络/限流）时，从缓存恢复 release 信息。
  /// 如果缓存中的 release.tagName 仍然大于当前版本 → 返回缓存 release，
  /// 让 UpdateDialog 正常弹出。
  static Future<GitHubRelease?> _checkCachedRelease() async {
    final cached = await _loadCachedRelease();
    if (cached == null) {
      appLogger.i('无缓存的 release 信息，跳过更新检查');
      return null;
    }

    final hasNewVersion = cached.isNewerThan(AppConstants.appVersion);
    if (hasNewVersion) {
      appLogger.i(
        '使用缓存的 release 信息: ${cached.tagName}（当前 ${AppConstants.appVersion}）',
      );
      return cached;
    }

    appLogger.i(
      '缓存的 release 已是旧版本 (app: ${AppConstants.appVersion} ≥ 缓存: ${cached.tagName})',
    );
    return null;
  }

  /// 从 SharedPreferences 读取缓存的 release 信息
  static Future<GitHubRelease?> _loadCachedRelease() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(AppConstants.keyCachedReleaseInfo);
      if (json == null || json.isEmpty) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      return GitHubRelease(
        tagName: data['tagName'] as String? ?? '',
        name: data['name'] as String? ?? '',
        body: data['body'] as String? ?? '',
        apkDownloadUrl: data['apkDownloadUrl'] as String? ?? '',
        apkFileName: data['apkFileName'] as String? ?? 'update.apk',
        publishedAt: DateTime.fromMillisecondsSinceEpoch(
          data['publishedAt'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
        ),
        prerelease: data['prerelease'] as bool? ?? false,
        forceUpdate: data['forceUpdate'] as bool? ?? false,
      );
    } catch (e) {
      appLogger.w('解析缓存 release 失败: $e');
      return null;
    }
  }
}
