import 'mixins/player_lifetime_mixin.dart';
import 'dart:async';
import 'dart:io' as dart_io;
import 'package:path/path.dart' as path;
import 'dart:ui' show Color, FontWeight;
import 'package:flutter/foundation.dart';
import 'package:flutter_mpv_video/flutter_mpv_video.dart';
import 'package:mpx/features/player/controller/mixins/volume_manager_mixin.dart';
import 'package:mpx/features/player/controller/mixins/brightness_manager_mixin.dart';
import 'package:mpx/features/player/controller/mixins/gesture_coordinator_mixin.dart'
    show GestureCoordinatorMixin;
import 'package:mpx/features/player/presentation/widgets/gesture_layer.dart'
    show SeekDirection;
import 'package:mpx/features/settings/services/app_settings_service.dart';
import 'utils/playback_wakelock.dart';
import '../../../core/services/logger_service.dart';
import '../../history/services/history_service.dart';
import '../../library/domain/entities/video_file.dart';
import '../domain/repositories/player_repository.dart';
import '../data/repositories/mpv_player_repository.dart';
import 'player_state.dart';
import 'mixins/gesture_handler_mixin.dart';
import 'mixins/subtitle_manager_mixin.dart';
import 'mixins/playback_control_mixin.dart';
import 'utils/time_formatter.dart' show formatTime;

export 'player_state.dart';
export 'utils/time_formatter.dart' show formatTime;
export '../domain/repositories/player_repository.dart' show AudioTrackInfo;

/// Controller for managing video player state and user interactions.
///
/// This controller follows the clean architecture pattern:
/// - Depends on [PlayerRepository] abstraction (not concrete implementation)
/// - Uses mixins to organize functionality into logical groups
/// - Provides ChangeNotifier for UI updates
class PlayerController extends ChangeNotifier
    with
        PlayerLifetimeMixin,
        GestureCoordinatorMixin,
        GestureHandlerMixin,
        SubtitleManagerMixin,
        PlaybackControlMixin,
        VolumeManagerMixin,
        BrightnessManagerMixin {
  final PlayerRepository _repository;
  final PlayerState _state = PlayerState();

  // Current video being played
  VideoFile? _currentVideo;

  // Auto-save timer for periodic position saves

  Timer? _autoSaveTimer;

  // Double-tap gesture tracking
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _tapTimer;
  static const _doubleTapTimeout = Duration(milliseconds: 200);

  // Last save timestamp for throttling
  DateTime? _lastSaveTime;

  // Throttle duration (minimum time between saves)
  static const Duration _saveThrottleDuration = Duration(seconds: 5);

  // Auto-save interval
  static const Duration _autoSaveInterval = Duration(seconds: 30);
  DateTime? _lastPositionUiUpdate;

  // Getters for state access
  @override
  PlayerRepository get repository => _repository;

  @override
  PlayerState get state => _state;

  // Convenience getters for UI
  bool get isPlaying => _state.isPlaying;
  bool get showControls => _state.showControls;
  bool get isBuffering => _state.isBuffering;
  bool get isFullscreen => _state.isFullscreen;
  Duration get position => _state.position;
  Duration get duration => _state.duration;
  @override
  double get volume => _state.volume;
  double get playbackSpeed => _state.playbackSpeed;
  bool get isLongPressing => _state.isLongPressing;
  @override
  bool get isLocked => _state.isLocked;
  bool get subtitlesEnabled => _state.subtitlesEnabled;
  double get subtitleFontSize => _state.subtitleFontSize;
  Color get subtitleColor => _state.subtitleColor;
  String get subtitleFontFamily => _state.subtitleFontFamily;
  bool get subtitleHasBackground => _state.subtitleHasBackground;
  FontWeight get subtitleFontWeight => _state.subtitleFontWeight;
  double get subtitleBottomPadding => _state.subtitleBottomPadding;
  double get subtitleBackgroundOpacity => _state.subtitleBackgroundOpacity;
  double get dragStartX => _state.dragStartX;
  bool get isDraggingX => _state.isDraggingX;
  bool get isDraggingY => _state.isDraggingY;
  String get verticalDragSide => _state.verticalDragSide;
  Duration get seekStartPosition => _state.seekStartPosition;
  bool get showSeekIndicator => _state.showSeekIndicator;
  String get seekDirection => _state.seekDirection;
  Duration get seekDelta => _state.seekDelta;
  bool get showVolumeIndicator => _state.showVolumeIndicator;
  bool get showBrightnessIndicator => _state.showBrightnessIndicator;
  double get brightnessValue => _state.brightnessValue;
  bool get showDoubleTapSeekLeft => _state.showDoubleTapSeekLeft;
  bool get showDoubleTapSeekRight => _state.showDoubleTapSeekRight;
  AspectRatioMode get aspectRatioMode => _state.aspectRatioMode;
  RepeatMode get repeatMode => _state.repeatMode;
  List<AudioTrackInfo> get audioTracks => _state.audioTracks;
  int get currentAudioTrackIndex => _state.currentAudioTrackIndex;
  List<SubtitleTrackInfo> get subtitleTracks => _state.subtitleTracks;
  int get currentSubtitleTrackIndex => _state.currentSubtitleTrackIndex;

  /// Returns the current video being played
  VideoFile? get currentVideo => _currentVideo;

  int get doubleTapSeekStep => _state.doubleTapSeekStep;
  double get dragSeekSensitivity => _state.dragSeekSensitivity;

  @override
  Future<void> loadExternalSubtitle(String path, {VideoFile? video}) async {
    final targetVideo = video ?? _currentVideo;
    if (targetVideo == null) return;
    await super.loadExternalSubtitle(path, video: targetVideo);
  }

  @override
  Future<void> setSubtitleTrack(int index, {VideoFile? video}) async {
    final targetVideo = video ?? _currentVideo;
    await super.setSubtitleTrack(index, video: targetVideo);
  }

  @override
  Future<void> setAudioTrack(int index, {VideoFile? video}) async {
    final targetVideo = video ?? _currentVideo;
    await super.setAudioTrack(index, video: targetVideo);
  }

  @override
  Future<void> setDoubleTapSeekStep(int seconds) async {
    super.setDoubleTapSeekStep(seconds);
    await AppSettingsService.setDoubleTapSeekStep(seconds);
  }

  @override
  Future<void> setDragSeekSensitivity(double sensitivity) async {
    super.setDragSeekSensitivity(sensitivity);
    await AppSettingsService.setDragSeekSensitivity(sensitivity);
  }

  /// Returns the underlying Player instance for VideoController creation.
  dynamic get player => (_repository as MpvPlayerRepository).player;

  /// Returns the VideoController for video rendering.
  late final VideoController videoController =
      VideoController((_repository as MpvPlayerRepository).player);

  /// Creates a PlayerController with dependency injection.
  late final Future<void> initialized;

  PlayerController(this._repository) {
    // Setup gesture coordination between mixins
    setupGestureCoordination(
      onSeekStart: startSeek,
      onSeekEnd: endSeek,
      onVolumeAdjustStart: startVolumeAdjust,
      onVolumeAdjustEnd: endVolumeAdjust,
      onBrightnessAdjustStart: startBrightnessAdjust,
      onBrightnessAdjustEnd: endBrightnessAdjust,
      shouldProcessVerticalDrag: shouldProcessVerticalDrag,
      shouldProcessLongPress: shouldProcessLongPress,
    );

    initializeSubtitles();
    initialized = Future.wait<void>([initializeVolume(), initializeBrightness()]).then((_) {});
    _loadSeekSettings();
    _setupListeners();
  }

  void _loadSeekSettings() {
    state.doubleTapSeekStep = AppSettingsService.doubleTapSeekStep;
    state.dragSeekSensitivity = AppSettingsService.dragSeekSensitivity;
  }

  void _setupListeners() {
    trackPlaybackSubscription(_repository.playingStream.listen((playing) {
      _state.isPlaying = playing;
      unawaited(PlaybackWakelock.setActive(this, playing));
      notifyListeners();
    }));

    trackPlaybackSubscription(_repository.positionStream.listen((pos) {
      if (_state.isDraggingX) return;

      _state.position = pos;
      final now = DateTime.now();
      final interval = _state.showControls ? 100 : 250;
      final shouldNotify = _lastPositionUiUpdate == null ||
          now.difference(_lastPositionUiUpdate!).inMilliseconds >= interval;

      if (shouldNotify) {
        _lastPositionUiUpdate = now;
        notifyListeners();
      }
    }));

    trackPlaybackSubscription(_repository.durationStream.listen((dur) {
      _state.duration = dur;
      notifyListeners();
    }));

    trackPlaybackSubscription(_repository.bufferingStream.listen((buffering) {
      _state.isBuffering = buffering;
      notifyListeners();
    }));

    trackPlaybackSubscription(_repository.subtitleTracksStream.listen((_) {
      loadSubtitleTracks();
    }));

    trackPlaybackSubscription(_repository.audioTracksStream.listen((_) {
      schedulePlaybackTask('audio-tracks', const Duration(milliseconds: 100), loadAudioTracks);
    }));

    trackPlaybackSubscription(_repository.completedStream.listen((completed) {
      if (completed) {
        // Video playback completed - reset position to 0
        resetPositionOnVideoEnd();
      }
    }));
  }

  /// Load a video file and start auto-save timer
  Future<void> loadVideoFile(VideoFile video) async {
    if (playbackDisposed) return;
    _currentVideo = video;
    _lastSaveTime = null;
    await initialized;
    if (playbackDisposed) return;
    await loadVideo(video.path);
    if (playbackDisposed || _currentVideo != video) return;
    await _applyPlayerPreset();
    if (playbackDisposed || _currentVideo != video) return;
    loadAudioTracks();
    loadSubtitleTracks();
    await applySubtitleSettings();
    if (playbackDisposed || _currentVideo != video) return;
    await _loadSidecarSubtitles(video);
    if (playbackDisposed || _currentVideo != video) return;
    await _loadPersistedSubtitles(video);
    if (playbackDisposed || _currentVideo != video) return;
    await loadSubtitleTracksWithRestore(video: video);
    if (playbackDisposed || _currentVideo != video) return;
    await loadAudioTracksWithRestore(video: video);
    if (playbackDisposed || _currentVideo != video) return;
    _startAutoSaveTimer();
  }

  bool _isCurrentVideo(VideoFile video) => !playbackDisposed && identical(_currentVideo, video);

  Future<void> _loadSidecarSubtitles(VideoFile video) async {
    final directory = dart_io.Directory(path.dirname(video.path));
    final base = path.basenameWithoutExtension(video.path).toLowerCase();
    const extensions = {'.srt', '.ass', '.ssa', '.sub', '.vtt', '.idx', '.smi'};
    final subtitlePaths = <String>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (!_isCurrentVideo(video)) return;
        if (entity is dart_io.File && extensions.contains(path.extension(entity.path).toLowerCase()) &&
            path.basenameWithoutExtension(entity.path).toLowerCase().startsWith(base)) {
          subtitlePaths.add(entity.path);
        }
      }
    } on dart_io.FileSystemException catch (error) {
      AppLogger.w('Unable to inspect sidecar subtitles: $error');
    }
    for (final subtitlePath in subtitlePaths) {
      if (!_isCurrentVideo(video)) return;
      try {
        await _repository.loadExternalSubtitle(subtitlePath);
      } catch (error) {
        if (!_isCurrentVideo(video)) return;
        AppLogger.w('Unable to load sidecar subtitle: $error');
      }
    }
    if (!_isCurrentVideo(video)) return;
    if (subtitlePaths.isNotEmpty) {
      final existing = await HistoryService.getSubtitlePaths(video.id);
      if (!_isCurrentVideo(video)) return;
      await HistoryService.saveSubtitlePaths(video.id, {...existing, ...subtitlePaths}.toList());
      if (!_isCurrentVideo(video)) return;
    }
    loadSubtitleTracks();
  }

  Future<void> _loadPersistedSubtitles(VideoFile video) async {
    final paths = await HistoryService.getSubtitlePaths(video.id);
    if (!_isCurrentVideo(video)) return;
    for (final subtitlePath in paths) {
      final exists = await dart_io.File(subtitlePath).exists();
      if (!_isCurrentVideo(video)) return;
      if (!exists) continue;
      try {
        await _repository.loadExternalSubtitle(subtitlePath);
      } catch (error) {
        if (!_isCurrentVideo(video)) return;
        AppLogger.w('Unable to restore subtitle: $error');
      }
    }
    if (_isCurrentVideo(video)) loadSubtitleTracks();
  }

  Future<void> _applyPlayerPreset() async {
    _state.playbackSpeed = AppSettingsService.presetPlaybackSpeed;
    _state.aspectRatioMode = AppSettingsService.presetAspectRatioMode;
    _state.repeatMode = AppSettingsService.presetRepeatMode;
    await _repository.setSpeed(_state.playbackSpeed);
    if (playbackDisposed) return;
    notifyListeners();
  }

  Future<void> applyVideoPerformanceProfile() async {
    await (_repository as MpvPlayerRepository)
        .applyVideoPerformanceConfiguration(
      AppSettingsService.videoPerformanceConfiguration,
    );
    if (playbackDisposed) return;
  }

  Future<void> syncKeepScreenAwakePreference() async {
    await PlaybackWakelock.setActive(this, _state.isPlaying);
    if (playbackDisposed) return;
  }

  // Use the formatTime utility from the utils file
  String formatDuration(Duration duration) => formatTime(duration);

  @override
  void seek(Duration position) {
    _state.position = position;
    super.seek(position);
  }

  /// Start the auto-save timer that saves position every 30 seconds
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      if (_state.isPlaying) {
        saveCurrentPosition();
      }
    });
  }

  /// Save current playback position to history
  /// Returns true if save was performed, false if throttled
  Future<bool> saveCurrentPosition({bool force = false}) async {
    // Check if we have a current video
    if (_currentVideo == null) {
      return false;
    }

    // Check if position is greater than 5 seconds (don't save at very beginning)
    if (_state.position.inSeconds < 5) {
      return false;
    }

    // Check throttling - don't save more than once every 5 seconds (unless forced)
    if (!force && _lastSaveTime != null) {
      final timeSinceLastSave = DateTime.now().difference(_lastSaveTime!);
      if (timeSinceLastSave < _saveThrottleDuration) {
        return false;
      }
    }

    // Perform the save
    _lastSaveTime = DateTime.now();
    await HistoryService.recordPlayback(
      video: _currentVideo!,
      position: _state.position,
      duration: _state.duration,
    );
    return true;
  }

  /// Save position when user pauses (always force — user explicitly paused)
  Future<void> savePositionOnPause() {
    return saveCurrentPosition(force: true);
  }

  /// Save position when app goes to background (always force — may not get another chance)
  Future<void> savePositionOnBackground() {
    return saveCurrentPosition(force: true);
  }

  @override
  void onPause() {
    savePositionOnPause();
  }

  /// Pause the video playback
  void pauseVideo() {
    _repository.pause();
    unawaited(PlaybackWakelock.setActive(this, false));
    _state.isPlaying = false;
    notifyListeners();
  }

  /// Reset position to 0 when video ends (video finished)
  Future<void> resetPositionOnVideoEnd() async {
    if (_currentVideo == null) return;

    await HistoryService.recordPlayback(
      video: _currentVideo!,
      position: Duration.zero,
      duration: _state.duration,
    );
  }

  /// Pre-dispose: await the final position save BEFORE the controller is disposed.
  /// Call this from the UI layer before Navigator.pop() triggers dispose().
  Future<void> saveAndCleanup() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    await saveCurrentPosition(force: true);
  }

  /// Handle tap gesture for double-tap seek detection
  void handleDoubleTap(SeekDirection direction) {
    // Block double-tap during seek or volume/brightness adjustment
    if (!shouldProcessDoubleTap()) return;

    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapTimeout) {
      _tapCount++;
      if (_tapCount == 2) {
        // Double tap detected - seek based on direction
        if (direction == SeekDirection.back) {
          seekBack();
        } else {
          seekForward();
        }
        _resetTapCounter();
        return;
      }
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;

    // Wait for possible second tap
    _tapTimer?.cancel();
    _tapTimer = Timer(_doubleTapTimeout, () {
      if (_tapCount == 1) {
        // Single tap on side zones - show controls
        showControlsNow();
      }
      _resetTapCounter();
    });
  }

  /// Handle center tap for double-tap pause/play
  void handleCenterTap() {
    // Block during seek or volume/brightness adjustment
    if (!shouldProcessDoubleTap()) return;

    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapTimeout) {
      _tapCount++;
      if (_tapCount == 2) {
        // Double tap detected - toggle pause/play
        togglePlayPause();
        _resetTapCounter();
        return;
      }
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;

    // Wait for possible second tap
    _tapTimer?.cancel();
    _tapTimer = Timer(_doubleTapTimeout, () {
      toggleControlsVisibility();
      _resetTapCounter();
    });
  }

  void _resetTapCounter() {
    _tapCount = 0;
    _lastTapTime = null;
    _tapTimer?.cancel();
    _tapTimer = null;
  }

  @override
  void dispose() {
    disposePlaybackLifetime();
    // Timer should already be cancelled by saveAndCleanup(),
    // but cancel again as a safety net.
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    // Cancel double-tap timer
    _tapTimer?.cancel();
    _tapTimer = null;

    unawaited(PlaybackWakelock.setActive(this, false));
    _repository.dispose();
    super.dispose();
  }
}
