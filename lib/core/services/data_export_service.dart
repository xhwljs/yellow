import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/data/models/favorite.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/repositories/favorite_repository.dart';
import 'package:yellow_depot/data/repositories/history_repository.dart';

/// 数据导出服务
///
/// 将收藏与播放历史导出为 JSON 文件，便于用户在卸载重装 / 换机时备份迁移。
///
/// 导出格式（JSON）：
/// ```json
/// {
///   "version": 1,
///   "exportedAt": "2026-07-28T12:00:00.000Z",
///   "favorites": [ { "videoId": "...", "title": "...", ... } ],
///   "histories": [ { "videoId": "...", "title": "...", ... } ]
/// }
/// ```
///
/// 导出方式：先写入临时文件，再调系统分享面板（share_plus），
/// 用户可选择"保存到文件"、"发送到聊天"等。不申请存储权限。
class DataExportService {
  DataExportService._();

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
        'version': 1,
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

  /// Favorite → JSON Map（只导出持久化字段，@ignore 字段不导出）
  static Map<String, dynamic> _favoriteToJson(Favorite f) => {
        'videoId': f.videoId,
        'title': f.title,
        'coverUrl': f.coverUrl,
        'categoryId': f.categoryId,
        'createdAt': f.createdAt,
      };

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
}
