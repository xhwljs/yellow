import 'package:videohub/data/models/video.dart';

/// 视频详情（不持久化，运行时构造）
class VideoDetail {
  final Video video;
  final String description;
  final String playUrl;
  final List<Video> relatedVideos;
  final String? token; // AK token，用于解密
  final String? sid;
  final String? nid;

  const VideoDetail({
    required this.video,
    required this.description,
    required this.playUrl,
    required this.relatedVideos,
    this.token,
    this.sid,
    this.nid,
  });

  VideoDetail copyWith({
    Video? video,
    String? description,
    String? playUrl,
    List<Video>? relatedVideos,
    String? token,
    String? sid,
    String? nid,
  }) {
    return VideoDetail(
      video: video ?? this.video,
      description: description ?? this.description,
      playUrl: playUrl ?? this.playUrl,
      relatedVideos: relatedVideos ?? this.relatedVideos,
      token: token ?? this.token,
      sid: sid ?? this.sid,
      nid: nid ?? this.nid,
    );
  }
}
