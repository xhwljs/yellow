import 'package:floor/floor.dart';

/// 播放历史（永久保存，按时间倒序）
@entity
class PlayHistory {
  @primaryKey
  final String videoId;

  final String title;
  final String coverUrl;
  final int categoryId;
  final int positionMs; // 上次播放位置（毫秒）
  final int durationMs; // 视频总时长（毫秒）
  final int updatedAt; // 最后播放时间戳

  const PlayHistory({
    required this.videoId,
    required this.title,
    required this.coverUrl,
    required this.categoryId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  /// 续播进度比例 0.0-1.0
  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// 是否已完成（>95% 视为已看完）
  bool get isCompleted => progress >= 0.95;
}
