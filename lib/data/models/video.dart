import 'package:floor/floor.dart';

/// 视频
@entity
class Video {
  @primaryKey
  final String id;

  final String title;
  final String coverUrl;
  final String duration;
  final String updateTime;
  final int playCount;
  final int likeCount;
  final int categoryId;

  const Video({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.updateTime,
    required this.playCount,
    required this.likeCount,
    required this.categoryId,
  });

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
      updateTime: map['updateTime'] as String? ?? '',
      playCount: map['playCount'] as int? ?? 0,
      likeCount: map['likeCount'] as int? ?? 0,
      categoryId: map['categoryId'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'coverUrl': coverUrl,
        'duration': duration,
        'updateTime': updateTime,
        'playCount': playCount,
        'likeCount': likeCount,
        'categoryId': categoryId,
      };

  Video copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? duration,
    String? updateTime,
    int? playCount,
    int? likeCount,
    int? categoryId,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      updateTime: updateTime ?? this.updateTime,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
