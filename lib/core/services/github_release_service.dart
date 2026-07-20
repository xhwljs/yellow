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

  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.apkDownloadUrl,
    required this.apkFileName,
    required this.publishedAt,
    required this.prerelease,
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

      return GitHubRelease(
        tagName: tagName,
        name: data['name'] as String? ?? tagName,
        body: data['body'] as String? ?? '',
        apkDownloadUrl: apkUrl,
        apkFileName: apkName ?? 'update.apk',
        publishedAt: publishedAt ?? DateTime.now(),
        prerelease: data['prerelease'] as bool? ?? false,
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
  /// 2. 解析 tag_name 与当前 AppConstants.appVersion 比较
  /// 3. 检查 assets 中是否有 APK 下载链接
  ///
  /// 返回 GitHubRelease 表示有新版本（含 APK 下载链接），否则返回 null。
  /// 不抛异常（内部捕获，失败时返回 null 让调用方静默跳过更新流程）。
  static Future<GitHubRelease?> checkForUpdate() async {
    try {
      final release = await getLatestRelease();
      if (release == null) return null;

      // 跳过预发布版本
      if (release.prerelease) {
        appLogger.i('最新 release 是预发布版本 ${release.tagName}，跳过');
        return null;
      }

      // 版本比较
      final hasNewVersion = release.isNewerThan(AppConstants.appVersion);
      if (!hasNewVersion) {
        appLogger.i('当前已是最新版本 (${AppConstants.appVersion} ≥ ${release.tagName})');
        return null;
      }

      appLogger.i('发现新版本：${release.tagName}（当前 ${AppConstants.appVersion}）');
      return release;
    } catch (e) {
      appLogger.w('检查更新失败: $e');
      return null;
    }
  }
}
