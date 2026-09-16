import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/core/utils/number_formatter.dart';

/// APK 下载进度回调
///
/// 参数：
/// - received：已接收字节数
/// - total：总字节数（未知时为 -1）
/// - progress：进度 0.0-1.0（total 未知时为 -1）
typedef DownloadProgressCallback = void Function(
  int received,
  int total,
  double progress,
);

/// 更新服务 — 下载 APK + 调用系统安装
///
/// 设计：
/// - 调用 GitHubReleaseService.checkForUpdate 检查新版本
/// - 用户确认后用 dio.download 下载 APK 到 /sdcard/Download/yellow_depot_v{tag}.apk
/// - 下载完成后用 open_file 包打开 APK 触发系统安装器
/// - Android 8+ 需 REQUEST_INSTALL_PACKAGES 权限（在 AndroidManifest 声明）
///
/// **限制**：
/// - 仅 Android 平台可用（iOS 不允许侧载，需走 App Store / TestFlight）
/// - 需要存储权限（保存 APK 到 Download 目录）
/// - 需要 REQUEST_INSTALL_PACKAGES 权限（安装未知来源 APK）
class AppUpdateService {
  /// 检查更新（不下载，仅返回 release 信息）
  ///
  /// 失败不抛异常，返回 null 让调用方静默跳过。
  static Future<GitHubRelease?> checkForUpdate() {
    return GitHubReleaseService.checkForUpdate();
  }

  /// 下载并安装 APK
  ///
  /// 流程：
  /// 1. 检查存储权限（Android 13+ 不需要，但低版本需要）
  /// 2. 下载 APK 到 /sdcard/Download/yellow_depot_v{tag}.apk
  /// 3. 调用 open_file 触发系统 APK 安装器
  ///
  /// 参数：
  /// - release：GitHubRelease（含 apkDownloadUrl）
  /// - onProgress：进度回调（0.0-1.0）
  ///
  /// 抛异常场景：
  /// - 权限拒绝
  /// - 下载失败（网络/写文件）
  /// - 打开 APK 安装器失败
  static Future<void> downloadAndInstall({
    required GitHubRelease release,
    DownloadProgressCallback? onProgress,
  }) async {
    appLogger.i('开始下载 APK: ${release.apkDownloadUrl}');

    // 1. 准备下载目录
    //
    // getExternalStorageDirectory 返回 /storage/emulated/0/Android/data/<pkg>/files
    // 但 Android 11+ 此目录其他应用不可读，APK 安装器无法访问。
    // 改用 getApplicationDocumentsDirectory 或 getDownloadsDirectory。
    //
    // open_file 4.x 内部会用 FileProvider 处理 Android 7+ 的 content:// URI，
    // 不需要担心其他应用是否可读，所以用 getApplicationDocumentsDirectory 即可。
    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/yellow_depot_${release.tagName}.apk';

    // 2. 下载 APK（镜像优先，直连兜底）
    //
    // github.com 的 release 下载会 302 到 objects.githubusercontent.com，
    // 国内基本无法直连；gh-proxy.com 镜像可代理下载（实测 200）。
    // 镜像失败再回退直连，保证海外网络同样可用。
    final downloadUrls = <String>[
      '${GitHubReleaseService.ghProxyPrefix}${release.apkDownloadUrl}',
      release.apkDownloadUrl,
    ];
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    try {
      Object? lastError;
      for (var i = 0; i < downloadUrls.length; i++) {
        try {
          appLogger.i('下载 APK（源 ${i + 1}/${downloadUrls.length}）: ${downloadUrls[i]}');
          await dio.download(
            downloadUrls[i],
            filePath,
            onReceiveProgress: (received, total) {
              if (onProgress != null && total > 0) {
                final progress = received / total;
                onProgress(received, total, progress);
              }
            },
          );
          // 魔数校验：APK 是 ZIP 格式（PK 开头），
          // 防止镜像返回 200 的 HTML 错误页被当作 APK 安装
          if (!_isZipFile(filePath)) {
            appLogger.w('下载的文件不是有效 APK（魔数校验失败），尝试下一个源');
            lastError = Exception('下载的文件无效（非 APK）');
            continue;
          }
          lastError = null;
          break;
        } on DioException catch (e) {
          appLogger.w('APK 下载失败（${downloadUrls[i]}）: ${e.message}');
          lastError = e;
        }
      }
      if (lastError != null) throw lastError;
      appLogger.i('APK 下载完成: $filePath (大小: ${NumberFormatter.formatBytes(_fileSize(filePath))})');
    } on DioException catch (e) {
      appLogger.e('APK 下载失败: ${e.message}');
      rethrow;
    } finally {
      dio.close();
    }

    // 2.5. 版本判断说明（无需 SharedPreferences）
    //
    // 之前用 SP 记录 lastInstalledReleaseTag 来判断是否已安装最新版本，
    // 但存在两个问题：
    // 1. 如果对话框没显示，下载流程根本不触发，SP 永远是空，重复提示更新
    // 2. 如果用户从 GitHub 直接下载 APK 手动安装，SP 不记录，仍会提示更新
    //
    // 现在改为：CI 在构建 APK 时把 tag（去掉 v 前缀）注入到
    // AppConstants.appVersion（见 .github/workflows/ci.yml build-android
    // 的 Inject appVersion step）。
    // 启动时 GitHubReleaseService.checkForUpdate 直接比较
    // AppConstants.appVersion 与 latest release.tagName（去掉 v 前缀）。
    // 这样无论用户从哪里安装 APK，appVersion 都是正确的，能正确判断是否最新版本。

    // 3. 打开 APK 安装器
    //
    // open_file 4.x 自动处理 Android 7+ 的 FileProvider content:// URI
    // 以及 Android 8+ 的 REQUEST_INSTALL_PACKAGES 权限引导
    final result = await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      appLogger.e('打开 APK 安装器失败: ${result.message}');
      throw Exception('打开 APK 安装器失败: ${result.message}');
    }
    appLogger.i('已唤起系统 APK 安装器');
  }

  /// 请求安装未知来源 APK 权限（Android 8+）
  ///
  /// 调用时机：在显示更新对话框之前预先请求。
  /// 用户授权后，下次调用 downloadAndInstall 才能成功唤起系统安装器。
  /// 返回 true 表示已授权（已授权或刚刚授权）。
  static Future<bool> requestInstallPermission() async {
    try {
      // ignore: unnecessary_type_check
      if (!kIsWeb) {
        // 使用 permission_handler 的 Permission.unknown.request()
        // 实际对应 Android 的 REQUEST_INSTALL_PACKAGES 权限。
        //
        // Android 8+ (API 26+) 必须声明此权限才能安装未知来源 APK。
        // Android 7 及以下不需要此权限，open_file 内部处理。
        final status = await Permission.requestInstallPackages.request();
        return status.isGranted;
      }
    } catch (e) {
      appLogger.w('请求安装权限异常: $e');
    }
    return false;
  }

  static int _fileSize(String path) {
    try {
      final file = io.File(path);
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// 校验文件是否为 ZIP 格式（APK 即 ZIP，魔数 'PK'）
  ///
  /// 用于下载完成后确认拿到的是真正的 APK，
  /// 而不是镜像 / CDN 返回 200 的 HTML 错误页。
  static bool _isZipFile(String path) {
    io.RandomAccessFile? raf;
    try {
      final file = io.File(path);
      if (!file.existsSync() || file.lengthSync() < 4) return false;
      raf = file.openSync();
      final bytes = raf.readSync(2);
      return bytes.length == 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    } catch (_) {
      return false;
    } finally {
      raf?.closeSync();
    }
  }
}
