import 'dart:async';

import 'package:floor/floor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/data/database/dao/category_dao.dart';
import 'package:videohub/data/database/dao/favorite_dao.dart';
import 'package:videohub/data/database/dao/history_dao.dart';
import 'package:videohub/data/database/dao/video_dao.dart';
import 'package:videohub/data/models/category.dart';
import 'package:videohub/data/models/favorite.dart';
import 'package:videohub/data/models/play_history.dart';
import 'package:videohub/data/models/video.dart';

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
  static Future<AppDatabase> build() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, AppConstants.databaseName);
    return $FloorAppDatabase.databaseBuilder(dbPath).build();
  }
}
