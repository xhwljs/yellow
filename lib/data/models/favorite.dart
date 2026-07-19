import 'package:floor/floor.dart';

/// 视频收藏（永久保存）
@entity
class Favorite {
  @primaryKey
  final String videoId;

  final String title;
  final String coverUrl;
  final int categoryId;
  final int createdAt;

  const Favorite({
    required this.videoId,
    required this.title,
    required this.coverUrl,
    required this.categoryId,
    required this.createdAt,
  });
}
