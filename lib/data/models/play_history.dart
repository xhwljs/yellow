import 'package:floor/floor.dart';

/// 播放历史（永久保存，按时间倒序）
///
/// **@ignore 字段说明**：
/// 详情展示字段（durationText/playCount/likeCount/updateTime）不持久化到数据库，
/// 避免触发 schema migration（曾经因 migration 卡死导致用户卸载重装）。
///
/// 这些字段在 [HistoryRepository.getAllHistory] 加载时
/// 从 VideoDao 缓存（Video 表）按 videoId 批量补全：
/// - VideoDao 命中 → 显示详情
/// - VideoDao 未命中 → 字段为默认空值，UI 自动隐藏对应行
///
/// 用户在详情页 upsertHistory 时会同步把 detail.video 写入 VideoDao，
/// 保证下次打开历史列表时能立即看到详情。
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

  /// 时长文本（如 "12:34"）— @ignore，运行时从 VideoDao 补全
  ///
  /// 注意：与 [durationMs] 不同。durationMs 是播放器内部用的毫秒数，
  /// durationText 是从站点解析的展示用文本（可能与 durationMs 不完全一致）。
  @ignore
  final String durationText;

  /// 播放次数 — @ignore，运行时从 VideoDao 补全
  @ignore
  final int playCount;

  /// 收藏次数 — @ignore，运行时从 VideoDao 补全
  @ignore
  final int likeCount;

  /// 更新时间（如 "08-20"）— @ignore，运行时从 VideoDao 补全
  @ignore
  final String updateTime;

  const PlayHistory({
    required this.videoId,
    required this.title,
    required this.coverUrl,
    required this.categoryId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    this.durationText = '',
    this.playCount = 0,
    this.likeCount = 0,
    this.updateTime = '',
  });

  /// 续播进度比例 0.0-1.0
  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// 是否已完成（>95% 视为已看完）
  bool get isCompleted => progress >= 0.95;

  /// 用 Video 详情补全 @ignore 字段，返回新实例
  PlayHistory withDetail({
    required String durationText,
    required int playCount,
    required int likeCount,
    required String updateTime,
  }) {
    return PlayHistory(
      videoId: videoId,
      title: title,
      coverUrl: coverUrl,
      categoryId: categoryId,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: updatedAt,
      durationText: durationText,
      playCount: playCount,
      likeCount: likeCount,
      updateTime: updateTime,
    );
  }
}
