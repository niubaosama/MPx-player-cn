import '../../../library/domain/entities/video_file.dart';

/// 普通播放与短视频切换时交接同一队列和播放状态。
class PlaybackTransfer {
  final List<VideoFile> videos;
  final int index;
  final Duration position;
  final double speed;
  final bool paused;
  const PlaybackTransfer({required this.videos, required this.index,
    required this.position, required this.speed, required this.paused});
  VideoFile get video => videos[index];
}
