import 'package:floor/floor.dart';

/// 视频收藏（永久保存）
///
/// **@ignore 字段说明**：
/// 详情展示字段（duration/playCount/likeCount/updateTime）不持久化到数据库，
/// 避免触发 schema migration（曾经因 migration 卡死导致用户卸载重装）。
///
/// 这些字段在 [FavoriteRepository.getAllFavorites] 加载时
/// 从 VideoDao 缓存（Video 表）按 videoId 批量补全：
/// - VideoDao 命中 → 显示详情
/// - VideoDao 未命中 → 字段为默认空值，UI 自动隐藏对应行
///
/// 用户在详情页 toggleFavorite 时会同步把 detail.video 写入 VideoDao，
/// 保证下次打开收藏列表时能立即看到详情。
@entity
class Favorite {
  @primaryKey
  final String videoId;

  final String title;
  final String coverUrl;
  final int categoryId;
  final int createdAt;

  /// 时长文本（如 "12:34"）— @ignore，运行时从 VideoDao 补全
  @ignore
  final String duration;

  /// 播放次数 — @ignore，运行时从 VideoDao 补全
  @ignore
  final int playCount;

  /// 收藏次数 — @ignore，运行时从 VideoDao 补全
  @ignore
  final int likeCount;

  /// 更新时间（如 "08-20"）— @ignore，运行时从 VideoDao 补全
  @ignore
  final String updateTime;

  const Favorite({
    required this.videoId,
    required this.title,
    required this.coverUrl,
    required this.categoryId,
    required this.createdAt,
    this.duration = '',
    this.playCount = 0,
    this.likeCount = 0,
    this.updateTime = '',
  });

  /// 用 Video 详情补全 @ignore 字段，返回新实例
  Favorite withDetail({
    required String duration,
    required int playCount,
    required int likeCount,
    required String updateTime,
  }) {
    return Favorite(
      videoId: videoId,
      title: title,
      coverUrl: coverUrl,
      categoryId: categoryId,
      createdAt: createdAt,
      duration: duration,
      playCount: playCount,
      likeCount: likeCount,
      updateTime: updateTime,
    );
  }
}
