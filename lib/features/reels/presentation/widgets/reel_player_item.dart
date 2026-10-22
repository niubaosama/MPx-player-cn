import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../library/domain/entities/video_file.dart';
import '../../../player/controller/player_controller.dart';
import '../../../player/data/repositories/mpv_player_repository.dart';
import '../../../player/presentation/widgets/player_surface.dart';
import '../../../player/presentation/widgets/playback_seek_bar.dart';

/// 仅当前可见页创建解码器，离开时释放；进度交还给外部会话。
class ReelPlayerItem extends StatefulWidget {
  final VideoFile video;
  final double playbackSpeed;
  final bool isPaused;
  final bool isMuted;
  final Duration initialPosition;
  final VoidCallback onTogglePause;
  final ValueChanged<Duration> onPosition;
  const ReelPlayerItem({super.key, required this.video,
    required this.playbackSpeed, required this.isPaused, required this.isMuted,
    required this.initialPosition, required this.onTogglePause, required this.onPosition});
  @override
  State<ReelPlayerItem> createState() => _ReelPlayerItemState();
}
class _ReelPlayerItemState extends State<ReelPlayerItem> {
  late final MpvPlayerRepository _repository;
  late final PlayerController _controller;
  bool _ready = false;
  String? _error;
  bool _seeking = false;
  bool _longPressing = false;
  @override
  void initState() {
    super.initState();
    _repository = MpvPlayerRepository(autoPlay: false);
    _controller = PlayerController(_repository);
    _controller.addListener(_rememberPosition);
    _controller.trackPlaybackSubscription(_repository.player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) setState(() => _error = error);
    }));
    _initialize();
  }
  void _rememberPosition() => widget.onPosition(_controller.position);
  Future<void> _initialize() async {
    try {
      await _controller.loadVideoFile(widget.video);
      if (!mounted) return;
      if (widget.initialPosition > Duration.zero) {
        await _repository.seek(widget.initialPosition);
        _controller.state.position = widget.initialPosition;
      }
      if (!mounted) return;
      _ready = true;
      await _syncPlayback();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }
  Future<void> _syncPlayback() async {
    if (!_ready || !mounted) return;
    await _repository.setSpeed(_longPressing ? 2 : widget.playbackSpeed);
    if (!mounted) return;
    await _repository.setVolume(widget.isMuted ? 0 : 100);
    if (!mounted) return;
    if (widget.isPaused || _seeking) {
      await _repository.pause();
    } else {
      await _repository.play();
    }
  }
  @override
  void didUpdateWidget(ReelPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused || widget.isMuted != oldWidget.isMuted ||
        widget.playbackSpeed != oldWidget.playbackSpeed) _syncPlayback();
  }
  void _endLongPress() {
    if (!_longPressing) return;
    setState(() => _longPressing = false);
    _syncPlayback();
  }
  @override
  void dispose() {
    widget.onPosition(_controller.position);
    _controller.removeListener(_rememberPosition);
    unawaited(_controller.saveCurrentPosition(force: true));
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(behavior: HitTestBehavior.opaque,
        onTap: widget.onTogglePause,
        onLongPressStart: (_) { setState(() => _longPressing = true); _syncPlayback(); },
        onLongPressEnd: (_) => _endLongPress(), onLongPressCancel: _endLongPress,
        child: PlayerSurface(controller: _controller.videoController,
          subtitleFontSize: _controller.subtitleFontSize,
          subtitleColor: _controller.subtitleColor,
          subtitleFontFamily: _controller.subtitleFontFamily,
          subtitleHasBackground: _controller.subtitleHasBackground,
          subtitleFontWeight: _controller.subtitleFontWeight,
          subtitleBottomPadding: 110,
          subtitleBackgroundOpacity: _controller.subtitleBackgroundOpacity)),
      if (_error != null) Center(child: Container(
        padding: const EdgeInsets.all(20), color: Colors.black87,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('Unable to play this video'), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text(_error!, maxLines: 3, style: const TextStyle(color: Colors.white60)),
          TextButton(onPressed: () {
            setState(() { _error = null; _ready = false; });
            _initialize();
          }, child: Text(context.tr('Retry'))),
        ]))),
      if (_error == null) AnimatedBuilder(animation: _controller, builder: (context, _) => Stack(children: [
        if (!_ready || _controller.isBuffering)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_ready && widget.isPaused)
          const Center(child: IgnorePointer(child: Icon(Icons.play_arrow_rounded, size: 72, color: Colors.white70))),
        if (_longPressing) const Positioned(top: 120, left: 0, right: 0,
          child: Center(child: Text('2.0×', style: TextStyle(color: Colors.white, fontSize: 20)))),
        Positioned(bottom: 0, left: 0, right: 0, child: SafeArea(top: false,
          child: Container(padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,
              end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.video.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
              PlaybackSeekBar(position: _controller.position, duration: _controller.duration,
                onSeekStart: () {
                  _seeking = true;
                  _controller.state.isDraggingX = true;
                  _repository.pause();
                },
                onSeekChanged: (value) => _controller.previewSeek(Duration(milliseconds: value.round())),
                onSeekEnd: (value) {
                  _controller.seek(Duration(milliseconds: value.round()));
                  _controller.state.isDraggingX = false;
                  _seeking = false;
                  _syncPlayback();
                }),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(formatTime(_controller.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(formatTime(_controller.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ])))),
      ])),
    ]);
  }
}
