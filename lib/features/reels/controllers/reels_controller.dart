import 'package:flutter/foundation.dart';
import 'package:mpx/features/reels/services/reel_service.dart';
import '../../library/domain/entities/video_file.dart';

enum ReelsSortOrder { dateDesc, dateAsc, nameAsc, shuffle }

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
  double _playbackSpeed = 1.0;
  bool _isPaused = false;

  List<VideoFile> get reelsVideos => _reelsVideos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ReelSource> get sources => List.unmodifiable(_sources);
  ReelsSortOrder get sortOrder => _sortOrder;
  double get playbackSpeed => _playbackSpeed;
  bool get isPaused => _isPaused;

  ReelsController({this.targetFolderPath, ReelService? service})
      : _service = service ?? ReelService() {
    loadReels();
  }

  Future<void> loadReels({bool forceRefresh = false}) {
    if (_loadFuture != null) return _loadFuture!;
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
      _reelsVideos = targetFolderPath == null
          ? await _service.getReelsVideos(forceRefresh: forceRefresh)
          : await _service.getVideosFromAnyFolder(targetFolderPath!, forceRefresh: forceRefresh);
      _applySort();
    } catch (e) {
      _error = 'Failed to load reels: $e';
    } finally {
      _isLoading = false;
      _loadFuture = null;
      _notify();
    }
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  void changeSortOrder(ReelsSortOrder order) {
    _sortOrder = order;
    _applySort();
    _notify();
  }

  void _applySort() {
    if (_reelsVideos.isEmpty) return;

    switch (_sortOrder) {
      case ReelsSortOrder.dateDesc:
        _reelsVideos.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case ReelsSortOrder.dateAsc:
        _reelsVideos.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case ReelsSortOrder.nameAsc:
        _reelsVideos.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case ReelsSortOrder.shuffle:
        _reelsVideos.shuffle();
        break;
    }
  }

  void togglePause() {
    _isPaused = !_isPaused;
    _notify();
  }

  void setPaused(bool paused) {
    if (_isPaused != paused) {
      _isPaused = paused;
      _notify();
    }
  }

  void cyclePlaybackSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    _playbackSpeed = speeds[(currentIndex + 1) % speeds.length];
    _notify();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _notify();
  }

  void resetPlaybackSpeed() {
    _playbackSpeed = 1.0;
    _notify();
  }

  Future<void> _changeSources(Future<void> Function() change) async {
    if (targetFolderPath != null) return;
    if (_loadFuture != null) await _loadFuture;
    await change();
    await loadReels();
  }

  Future<void> importFolderToReels(String folderPath) =>
      _changeSources(() => _service.importFolder(folderPath));

  Future<void> importVideoToReels(String filePath) =>
      _changeSources(() => _service.importVideoFile(filePath));

  Future<void> removeSource(String path) =>
      _changeSources(() => _service.removeSource(path));

  Future<void> setIncludeSubfolders(String path, bool enabled) =>
      _changeSources(() => _service.setIncludeSubfolders(path, enabled));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
