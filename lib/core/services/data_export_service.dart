import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/favorite.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';

/// 数据导入导出服务
///
/// 将收藏与播放历史导出为 JSON 文件、从 JSON 文件导入，
/// 便于用户在卸载重装 / 换机时备份迁移。
///
/// 备份格式（JSON）：
/// ```json
/// {
///   "version": 1,
///   "exportedAt": "2026-07-28T12:00:00.000Z",
///   "favorites": [ { "videoId": "...", "title": "...", ... } ],
///   "histories": [ { "videoId": "...", "title": "...", ... } ]
/// }
/// ```
///
/// 导出方式：写入临时文件 → 系统分享面板（share_plus），不申请存储权限。
/// 导入方式：系统文件选择器（file_picker）选 JSON 文件 → 解析 → merge 入库。
class DataExportService {
  DataExportService._();

  /// 备份格式版本号（用于未来格式升级时的兼容判断）
  static const int kBackupVersion = 1;

  /// 导出收藏 + 历史为 JSON 文件，并弹出系统分享面板。
  ///
  /// 返回 true 表示分享面板成功弹出（不代表用户最终保存成功）；
  /// 返回 false 表示导出失败（已弹 snackbar 提示原因）。
  static Future<bool> exportAll({
    required FavoriteRepository favoriteRepo,
    required HistoryRepository historyRepo,
  }) async {
    try {
      appLogger.i('开始导出收藏 + 播放历史');

      final favorites = await favoriteRepo.getAllFavorites();
      final histories = await historyRepo.getAllHistory();

      final payload = {
        'version': kBackupVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'favorites': favorites.map(_favoriteToJson).toList(),
        'histories': histories.map(_historyToJson).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
      final bytes = utf8.encode(jsonStr);

      // 写入临时文件
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toLocal()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]+'), '-')
          .substring(0, 19);
      final fileName = 'yellow_depot_backup_$stamp.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      appLogger.i(
        '导出完成：${favorites.length} 条收藏 + ${histories.length} 条历史，'
        '文件：${file.path}（${bytes.length} bytes）',
      );

      // 弹出系统分享面板
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Yellow Depot 备份 · $fileName',
        text: 'Yellow Depot 数据备份（${favorites.length} 收藏 / '
            '${histories.length} 历史）',
      );

      return true;
    } catch (e, st) {
      appLogger.e('导出失败', error: e, stackTrace: st);
      return false;
    }
  }

  /// 从用户选择的 JSON 文件导入收藏 + 历史。
  ///
  /// 采用 merge 策略：同 videoId 已存在则覆盖，不存在则插入，不清空现有数据。
  ///
  /// 返回 [ImportResult]：
  /// - ok=true 表示导入成功（含导入条数）
  /// - ok=false 表示导入失败（用户取消 / 文件读取失败 / JSON 格式错误）
  static Future<ImportResult> importAll({
    required FavoriteRepository favoriteRepo,
    required HistoryRepository historyRepo,
  }) async {
    try {
      // 系统文件选择器，只允许选 JSON
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      // 用户取消选择
      if (result == null || result.files.isEmpty) {
        appLogger.i('导入：用户取消文件选择');
        return const ImportResult(ok: false, reason: '已取消');
      }

      final file = result.files.first;
      String? jsonStr;

      // 优先用已读取的字节数据（withData: true）
      if (file.bytes != null) {
        jsonStr = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        // 桌面 / 某些 Android 场景 bytes 为空，从路径读
        jsonStr = await File(file.path!).readAsString();
      }

      if (jsonStr == null || jsonStr.isEmpty) {
        appLogger.w('导入：文件内容为空');
        return const ImportResult(ok: false, reason: '文件内容为空');
      }

      // 解析 JSON
      late final Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map<String, dynamic>) {
          appLogger.w('导入：JSON 根不是对象');
          return const ImportResult(ok: false, reason: '备份文件格式错误');
        }
        payload = decoded;
      } catch (e) {
        appLogger.w('导入：JSON 解析失败: $e');
        return const ImportResult(ok: false, reason: '备份文件不是有效的 JSON');
      }

      // 校验版本号
      final version = payload['version'];
      if (version != kBackupVersion) {
        appLogger.w('导入：备份版本不匹配（文件=$version，预期=$kBackupVersion）');
        return ImportResult(
          ok: false,
          reason: '备份版本不兼容（文件版本 $version，当前支持 $kBackupVersion）',
        );
      }

      // 解析收藏列表
      final favList = payload['favorites'];
      final favorites = <Favorite>[];
      if (favList is List) {
        for (final item in favList) {
          final fav = _favoriteFromJson(item);
          if (fav != null) favorites.add(fav);
        }
      }

      // 解析历史列表
      final histList = payload['histories'];
      final histories = <PlayHistory>[];
      if (histList is List) {
        for (final item in histList) {
          final h = _historyFromJson(item);
          if (h != null) histories.add(h);
        }
      }

      appLogger.i(
        '导入解析：${favorites.length} 条收藏 + ${histories.length} 条历史，'
        '开始写入数据库',
      );

      // merge 入库（同 videoId 覆盖，不清空现有数据）
      final importedFav = favorites.isEmpty
          ? 0
          : await favoriteRepo.importFavorites(favorites);
      final importedHist = histories.isEmpty
          ? 0
          : await historyRepo.importHistories(histories);

      appLogger.i(
        '导入完成：收藏 $importedFav/${favorites.length}，'
        '历史 $importedHist/${histories.length}',
      );

      return ImportResult(
        ok: true,
        reason: '收藏 +$importedFav / 历史 +$importedHist',
        favoritesImported: importedFav,
        historiesImported: importedHist,
      );
    } catch (e, st) {
      appLogger.e('导入失败', error: e, stackTrace: st);
      return ImportResult(ok: false, reason: '导入失败：$e');
    }
  }

  /// Favorite → JSON Map（只导出持久化字段，@ignore 字段不导出）
  static Map<String, dynamic> _favoriteToJson(Favorite f) => {
        'videoId': f.videoId,
        'title': f.title,
        'coverUrl': f.coverUrl,
        'categoryId': f.categoryId,
        'createdAt': f.createdAt,
      };

  /// JSON Map → Favorite（导入时用，只读持久化字段）
  static Favorite? _favoriteFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final videoId = json['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;
    return Favorite(
      videoId: videoId,
      title: (json['title'] as String?) ?? '',
      coverUrl: (json['coverUrl'] as String?) ?? '',
      categoryId: (json['categoryId'] as int?) ?? 0,
      createdAt: (json['createdAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// PlayHistory → JSON Map（只导出持久化字段，@ignore 字段不导出）
  static Map<String, dynamic> _historyToJson(PlayHistory h) => {
        'videoId': h.videoId,
        'title': h.title,
        'coverUrl': h.coverUrl,
        'categoryId': h.categoryId,
        'positionMs': h.positionMs,
        'durationMs': h.durationMs,
        'updatedAt': h.updatedAt,
      };

  /// JSON Map → PlayHistory（导入时用，只读持久化字段）
  static PlayHistory? _historyFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final videoId = json['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;
    return PlayHistory(
      videoId: videoId,
      title: (json['title'] as String?) ?? '',
      coverUrl: (json['coverUrl'] as String?) ?? '',
      categoryId: (json['categoryId'] as int?) ?? 0,
      positionMs: (json['positionMs'] as int?) ?? 0,
      durationMs: (json['durationMs'] as int?) ?? 0,
      updatedAt: (json['updatedAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 导入结果
class ImportResult {
  final bool ok;
  final String reason;

  /// 成功导入的收藏条数
  final int favoritesImported;

  /// 成功导入的历史条数
  final int historiesImported;

  const ImportResult({
    required this.ok,
    required this.reason,
    this.favoritesImported = 0,
    this.historiesImported = 0,
  });
}
