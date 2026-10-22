import 'package:flutter/material.dart';

/// 普通播放和短视频共用的进度条，拖动时只预览，松手后定位一次。
class PlaybackSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final VoidCallback onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  const PlaybackSeekBar({super.key, required this.position, required this.duration,
    required this.onSeekStart, required this.onSeekChanged, required this.onSeekEnd});
  @override
  State<PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}
class _PlaybackSeekBarState extends State<PlaybackSeekBar> {
  double? _preview;
  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    return SizedBox(height: 48, child: SliderTheme(
      data: SliderTheme.of(context).copyWith(trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        activeTrackColor: Colors.white, inactiveTrackColor: Colors.white30,
        thumbColor: Colors.white, overlayColor: Colors.white12),
      child: Slider(value: (_preview ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, max),
        max: max,
        onChangeStart: widget.duration > Duration.zero ? (_) => widget.onSeekStart() : null,
        onChanged: widget.duration > Duration.zero ? (value) {
          setState(() => _preview = value);
          widget.onSeekChanged(value);
        } : null,
        onChangeEnd: widget.duration > Duration.zero ? (value) {
          widget.onSeekEnd(value);
          if (mounted) { setState(() => _preview = null); }
        } : null),
    ));
  }
}
