import 'package:dio/dio.dart';
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
      appLogger.w('GitHub API 请求失败: ${e.message}，尝试 fallback 解析');
      // Fallback: api.github.com 不可达时，尝试用 github.com 的
      // /releases/latest 页面 302 redirect 解析 tag_name
      final fallback = await _fetchLatestReleaseFromRedirect();
      if (fallback != null) return fallback;
      rethrow;
    } finally {
      dio.close();
    }
  }

  /// Fallback：通过 GitHub Releases 页面 302 redirect 解析最新 release
  ///
  /// 调用场景：api.github.com 不可达（中国大陆常见，DNS 污染或网络问题），
  /// 但 github.com 仍可访问时使用。
  ///
  /// 流程：
  /// 1. GET https://github.com/xhwljs/yellow/releases/latest （不跟随重定向）
  /// 2. 拿到 302 Location，形如 /xhwljs/yellow/releases/tag/v2026.0720.6
  /// 3. 正则提取 tag_name = v2026.0720.6
  /// 4. 比较 tag_name（去掉 v）与 AppConstants.appVersion
  /// 5. 若有新版本 → 构造 GitHubRelease（assets URL 用固定路径推断）：
  ///    - apkDownloadUrl = https://github.com/{owner}/{repo}/releases/download/{tag}/{apkName}
  ///    - body = ""（无法获取 release body，无法判断是否强制更新）
  ///    - forceUpdate = true（保守：当 API 不可达时按强制更新处理，避免漏弹）
  ///
  /// 返回值：
  /// - 有新版本 → 返回 GitHubRelease
  /// - 无新版本 / 网络也失败 → 返回 null
  static Future<GitHubRelease?> _fetchLatestReleaseFromRedirect() async {
    final url = 'https://github.com/$repoOwner/$repoName/releases/latest';
    appLogger.i('Fallback: 通过 GitHub Releases 页面 302 解析 tag: $url');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      followRedirects: false, // 不跟随，拿原始 302 Location
      validateStatus: (s) => s != null,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ));

    try {
      final resp = await dio.get<dynamic>(url);
      final location = resp.headers.value('location');
      if (location == null || location.isEmpty) {
        appLogger.w('Fallback: GitHub 返回无 Location header');
        return null;
      }
      // Location 形如：/xhwljs/yellow/releases/tag/v2026.0720.6
      // 或完整 URL：https://github.com/xhwljs/yellow/releases/tag/v2026.0720.6
      final tagMatch = RegExp(r'/releases/tag/(v?[0-9][^/?#]+)').firstMatch(location);
      if (tagMatch == null) {
        appLogger.w('Fallback: Location 中未匹配到 tag_name: $location');
        return null;
      }
      final tagName = tagMatch.group(1)!;

      // 比较版本号：若不大于当前版本，不弹对话框
      final release = GitHubRelease(
        tagName: tagName,
        name: 'Release $tagName',
        body: '', // 无法获取 release body，无法判断是否强制更新
        // APK URL 用固定路径推断（CI 构建产物固定命名）
        apkDownloadUrl:
            'https://github.com/$repoOwner/$repoName/releases/download/$tagName/$apkAssetName',
        apkFileName: apkAssetName,
        publishedAt: DateTime.now(),
        prerelease: false,
        // 无法获取 release body → 无法判断是否强制更新
        // 改为 false（非强制），让用户可选"稍后"，避免误强制更新
        forceUpdate: false,
      );

      if (!release.isNewerThan(AppConstants.appVersion)) {
        appLogger.i('Fallback: GitHub 上 tag $tagName 不大于当前版本 ${AppConstants.appVersion}，跳过');
        return null;
      }
      appLogger.i('Fallback: 解析到最新 tag $tagName，构造 release');
      return release;
    } catch (e) {
      appLogger.w('Fallback: GitHub Releases 页面 302 解析失败: $e');
      return null;
    } finally {
      dio.close();
    }
  }

  /// CI 构建产物的固定 APK 文件名（与 .github/workflows/ci.yml 一致）
  static const String apkAssetName = 'app-arm64-v8a-debug.apk';

  /// 检查是否有新版本可用
  ///
  /// 流程：
  /// 1. 调用 GitHub API 拿最新 release
  /// 2. 跳过预发布版本
  /// 3. 比较 release.tagName 与 [AppConstants.appVersion]
  ///    - 相同 → 已是最新版本，返回 null
  ///    - release.tagName 更大 → 返回 release
  /// 4. 任何步骤失败（网络问题/限流）→ 返回 null（不弹更新）
  ///
  /// **为什么移除缓存机制**：
  /// 之前发现新版本时会缓存到 SharedPreferences，API 失败时从缓存恢复。
  /// 但这导致用户从旧版本（如 5）更新时，可能弹缓存的中间版本（如 6）
  /// 而不是最新版本（如 8），用户被迫先更新到 6 再到 7 再到 8。
  /// 现在移除缓存：API 成功时总是用 GitHub 上的最新版本（8），
  /// API 失败时不弹更新（让用户下次启动时再试），确保用户直接从 5 更新到 8。
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
  /// 不抛异常（内部捕获，失败时返回 null 让调用方静默跳过更新流程）。
  static Future<GitHubRelease?> checkForUpdate() async {
    try {
      final release = await getLatestRelease();
      if (release == null) {
        appLogger.i('GitHub API 返回无 release，跳过更新检查');
        return null;
      }

      // 跳过预发布版本
      if (release.prerelease) {
        appLogger.i('最新 release 是预发布版本 ${release.tagName}，跳过');
        return null;
      }

      // 版本比较：release.tagName（去掉 v 前缀）vs AppConstants.appVersion
      final hasNewVersion = release.isNewerThan(AppConstants.appVersion);
      if (hasNewVersion) {
        appLogger.i(
          '发现新版本：${release.tagName}（当前 ${AppConstants.appVersion}，'
          '强制更新: ${release.forceUpdate}）',
        );
        return release;
      }

      // 当前已是最新版本 → 不需要更新
      appLogger.i(
        '当前已是最新版本 (app: ${AppConstants.appVersion} ≥ release: ${release.tagName})',
      );
      return null;
    } catch (e) {
      // GitHub API 调用失败 → 不弹更新（让用户下次启动时再试）
      // 不再用缓存的旧版本，避免用户被迫更新到中间版本
      appLogger.w('检查更新失败: $e，跳过本次更新检查');
      return null;
    }
  }
}
