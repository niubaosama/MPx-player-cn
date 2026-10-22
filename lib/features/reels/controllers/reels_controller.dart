import 'dart:collection';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/features/reels/services/reel_service.dart';
import '../../library/domain/entities/video_file.dart';

enum ReelsSortOrder { dateDesc, dateAsc, nameAsc, shuffle }
enum ReelsSourceMode { folders, localRandom }

/// 页面只负责呈现，队列与播放意图由会话持有，切换栏目不会重新洗牌。
class ReelsController extends ChangeNotifier {
  List<VideoFile> _reelsVideos = [];
  bool _isLoading = false;
  String? _error;
  final ReelService _service;
  List<ReelSource> _sources = [];
  bool _disposed = false;
  Future<void>? _loadFuture;
  final String? targetFolderPath;
  ReelsSortOrder _sortOrder = ReelsSortOrder.dateDesc;
  ReelsSourceMode _sourceMode = ReelsSourceMode.folders;
  double _playbackSpeed = 1.0;
  bool _isPaused = false;
  bool _isMuted = false;
  int _currentIndex = 0;
  int _queueRevision = 0;
  late final Future<void> initialized;
  final Map<String, Duration> _positions = {};
  final Map<ReelsSourceMode, List<VideoFile>> _modeQueues = {};
  final Map<ReelsSourceMode, String?> _modeCurrentPaths = {};
  final Map<ReelsSourceMode, ReelsSortOrder> _modeSortOrders = {};

  List<VideoFile> get reelsVideos => UnmodifiableListView(_reelsVideos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ReelSource> get sources => List.unmodifiable(_sources);
  ReelsSortOrder get sortOrder => _sortOrder;
  ReelsSourceMode get sourceMode => _sourceMode;
  double get playbackSpeed => _playbackSpeed;
  bool get isPaused => _isPaused;
  bool get isMuted => _isMuted;
  int get currentIndex => _currentIndex;
  int get queueRevision => _queueRevision;
  VideoFile? get currentVideo => _reelsVideos.isEmpty ? null : _reelsVideos[_currentIndex];
  Duration positionFor(String path) => _positions[path] ?? Duration.zero;

  ReelsController({this.targetFolderPath, ReelService? service,
    List<VideoFile>? initialVideos, String? initialVideoPath,
    Duration initialPosition = Duration.zero, double initialSpeed = 1,
    bool initiallyPaused = false}) : _service = service ?? ReelService() {
    _playbackSpeed = initialSpeed;
    _isPaused = initiallyPaused;
    if (initialVideos != null && initialVideos.isNotEmpty) {
      _reelsVideos = List.of(initialVideos);
      _selectPath(initialVideoPath);
      if (initialVideoPath != null) { _positions[initialVideoPath] = initialPosition; }
      initialized = Future.value();
    } else {
      initialized = _initialize();
    }
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) { return; }
    if (targetFolderPath == null && prefs.getString('reels_source_mode') == ReelsSourceMode.localRandom.name) {
      _sourceMode = ReelsSourceMode.localRandom;
      _sortOrder = ReelsSortOrder.shuffle;
    }
    await loadReels();
  }

  Future<void> loadReels({bool forceRefresh = false}) {
    if (_loadFuture != null) { return _loadFuture!; }
    final future = _loadReels(forceRefresh);
    _loadFuture = future;
    return future;
  }
  Future<void> _loadReels(bool forceRefresh) async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _sources = await _service.getSources();
      final found = targetFolderPath != null
          ? await _service.getVideosFromAnyFolder(targetFolderPath!, forceRefresh: forceRefresh)
          : _sourceMode == ReelsSourceMode.localRandom
            ? await _service.getLocalVideos(forceRefresh: forceRefresh)
            : await _service.getReelsVideos(forceRefresh: forceRefresh);
      if (_disposed) { return; }
      final currentPath = currentVideo?.path;
      final byPath = {for (final video in found) video.path: video};
      // 刷新只合并新增和移除，不打乱正在观看的会话。
      final previous = _reelsVideos.where((video) => byPath.containsKey(video.path)).toList();
      final previousPaths = previous.map((video) => video.path).toSet();
      final added = found.where((video) => !previousPaths.contains(video.path)).toList();
      _reelsVideos = [...previous.map((video) => byPath[video.path]!), ...added];
      if (previous.isEmpty || _sortOrder != ReelsSortOrder.shuffle) { _applySort(); }
      _selectPath(currentPath);
      _queueRevision++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _loadFuture = null;
      _notify();
    }
  }
  void _selectPath(String? path) {
    final index = path == null ? -1 : _reelsVideos.indexWhere((video) => video.path == path);
    _currentIndex = index >= 0 ? index : 0;
  }
  void _notify() { if (!_disposed) notifyListeners(); }
  void selectIndex(int index) {
    if (index < 0 || index >= _reelsVideos.length || index == _currentIndex) { return; }
    _currentIndex = index;
    _notify();
  }
  void rememberPosition(String path, Duration position) {
    if (position >= Duration.zero) { _positions[path] = position; }
  }
  void selectVideo(String path, Duration position, double speed, bool paused) {
    _selectPath(path);
    _positions[path] = position;
    _playbackSpeed = speed;
    _isPaused = paused;
    _queueRevision++;
    _notify();
  }
  Future<void> setSourceMode(ReelsSourceMode mode) async {
    if (mode == _sourceMode || targetFolderPath != null) { return; }
    if (_loadFuture != null) { await _loadFuture; }
    _modeQueues[_sourceMode] = List.of(_reelsVideos);
    _modeCurrentPaths[_sourceMode] = currentVideo?.path;
    _modeSortOrders[_sourceMode] = _sortOrder;
    _sourceMode = mode;
    _sortOrder = _modeSortOrders[mode] ?? (mode == ReelsSourceMode.localRandom ? ReelsSortOrder.shuffle : ReelsSortOrder.dateDesc);
    _reelsVideos = List.of(_modeQueues[mode] ?? []);
    _selectPath(_modeCurrentPaths[mode]);
    _queueRevision++;
    _notify();
    await loadReels();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reels_source_mode', mode.name);
  }
  void changeSortOrder(ReelsSortOrder order) {
    final currentPath = currentVideo?.path;
    _sortOrder = order;
    _applySort();
    _selectPath(currentPath);
    _queueRevision++;
    _notify();
  }
  void _applySort() {
    switch (_sortOrder) {
      case ReelsSortOrder.dateDesc: _reelsVideos.sort((a,b) => b.dateAdded.compareTo(a.dateAdded)); break;
      case ReelsSortOrder.dateAsc: _reelsVideos.sort((a,b) => a.dateAdded.compareTo(b.dateAdded)); break;
      case ReelsSortOrder.nameAsc: _reelsVideos.sort((a,b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case ReelsSortOrder.shuffle: _reelsVideos.shuffle(); break;
    }
  }
  void togglePause() { _isPaused = !_isPaused; _notify(); }
  void setPaused(bool paused) { if (_isPaused != paused) { _isPaused = paused; _notify(); } }
  void toggleMute() { _isMuted = !_isMuted; _notify(); }
  void cyclePlaybackSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    setPlaybackSpeed(speeds[(speeds.indexOf(_playbackSpeed) + 1) % speeds.length]);
  }
  void setPlaybackSpeed(double speed) { _playbackSpeed = speed; _notify(); }
  void resetPlaybackSpeed() => setPlaybackSpeed(1);
  Future<void> _changeSources(Future<void> Function() change) async {
    if (targetFolderPath != null) { return; }
    if (_loadFuture != null) { await _loadFuture; }
    await change();
    await loadReels();
  }
  Future<void> importFolderToReels(String path) => _changeSources(() => _service.importFolder(path));
  Future<void> importVideoToReels(String path) => _changeSources(() => _service.importVideoFile(path));
  Future<void> removeSource(String path) => _changeSources(() => _service.removeSource(path));
  Future<void> setIncludeSubfolders(String path, bool enabled) => _changeSources(() => _service.setIncludeSubfolders(path, enabled));
  @override
  void dispose() { _disposed = true; super.dispose(); }
}
