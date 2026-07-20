import 'dart:async';

import 'package:floor/floor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/data/database/dao/category_dao.dart';
import 'package:yellow_depot/data/database/dao/favorite_dao.dart';
import 'package:yellow_depot/data/database/dao/history_dao.dart';
import 'package:yellow_depot/data/database/dao/video_dao.dart';
import 'package:yellow_depot/data/models/category.dart';
import 'package:yellow_depot/data/models/favorite.dart';
import 'package:yellow_depot/data/models/play_history.dart';
import 'package:yellow_depot/data/models/video.dart';

part 'app_database.g.dart';

/// AppDatabase — Floor 数据库
///
/// Flutter 适配版 Room Database。
/// 运行 `flutter pub run build_runner build` 生成 app_database.g.dart
@Database(
  version: AppConstants.databaseVersion,
  entities: [Category, Video, PlayHistory, Favorite],
)
abstract class AppDatabase extends FloorDatabase {
  CategoryDao get categoryDao;
  VideoDao get videoDao;
  HistoryDao get historyDao;
  FavoriteDao get favoriteDao;

  /// 工厂构造 — 初始化数据库到应用文档目录
  ///
  /// 包含 migration 1→2：
  /// - 旧版本 CategoryParser 只解析导航菜单（无 count）
  /// - 新版本优先解析首页"目录"区块（.stui-pannel__menu，含 count 视频数量）
  /// - 清空 Category + Video 表强制重新拉取，让用户立即看到目录卷帘菜单的 count
  static Future<AppDatabase> build() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, AppConstants.databaseName);

    final callback = Callback(
      onCreate: (db, version) async {
        // Floor 已通过 @Database entities 自动建表，这里无需额外操作
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 1→2: 清空旧分类缓存（无 count），强制重新解析首页"目录"区块
          await db.execute('DELETE FROM Category');
          await db.execute('DELETE FROM Video');
        }
      },
    );

    return $FloorAppDatabase
        .databaseBuilder(dbPath)
        .addCallback(callback)
        .build();
  }
}
