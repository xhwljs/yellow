import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/utils/logger.dart';

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

    // 2. 下载 APK
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ));
    try {
      await dio.download(
        release.apkDownloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            final progress = received / total;
            onProgress(received, total, progress);
          }
        },
      );
      appLogger.i('APK 下载完成: $filePath (大小: ${_formatBytes(_fileSize(filePath))})');
    } on DioException catch (e) {
      appLogger.e('APK 下载失败: ${e.message}');
      rethrow;
    } finally {
      dio.close();
    }

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

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIdx = 0;
    while (size >= 1024 && unitIdx < units.length - 1) {
      size /= 1024;
      unitIdx++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIdx]}';
  }
}
