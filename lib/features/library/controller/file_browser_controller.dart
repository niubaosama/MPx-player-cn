import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/logger_service.dart';
import '../domain/entities/file_item.dart';
import '../data/datasources/directory_browser.dart';
import '../services/library_index_service.dart';
import '../services/library_preferences_service.dart';
import '../utils/sort_utils.dart';

enum SortBy { name, date, size, videos }

enum SortOrder { ascending, descending }

class FileBrowserController extends ChangeNotifier {
  static String? _persistedCurrentPath;
  static List<String> _persistedPathHistory = <String>[];

  static final FileBrowserController _instance = FileBrowserController._internal();
  factory FileBrowserController() => _instance;
  FileBrowserController._internal() : _browser = DirectoryBrowser(),
      _indexService = LibraryIndexService() {
    _indexService.addListener(_onIndexChanged);
  }

  @visibleForTesting
  FileBrowserController.forTesting(this._browser, this._indexService) {
    _indexService.addListener(_onIndexChanged);
  }

  final DirectoryBrowser _browser;
  final LibraryIndexService _indexService;

  List<FileItem> _items = [];
  List<FileItem> _directoryItems = [];
  int _visibilityRevision = 0;
  bool _disposed = false;
  final List<String> _pathHistory = [];
  String _currentPath = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _showOnlyVideos = true;
  SortBy _sortBy = SortBy.name;
  SortOrder _sortOrder = SortOrder.ascending;
  String? _error;
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;

  // Navigation debounce
  bool _isNavigating = false;

  // File system watcher
  StreamSubscription<FileSystemEvent>? _dirWatcherSub;
  Timer? _watcherDebounce;

  List<FileItem> get items => _items;
  String get currentPath => _currentPath;
  List<String> get pathHistory => _pathHistory;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get showOnlyVideos => _showOnlyVideos;
  SortBy get sortBy => _sortBy;
  SortOrder get sortOrder => _sortOrder;
  String? get error => _error;
  bool get canGoBack => _pathHistory.isNotEmpty;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedItems => _selectedItems;
  int get selectedCount => _selectedItems.length;

  // Public getter for root path
  String get getRootPath => _browser.getRootPath();

  Future<void> initialize() async {
    _showOnlyVideos = LibraryPreferencesService.showOnlyVideos;
    _sortBy = LibraryPreferencesService.sortBy;
    _sortOrder = LibraryPreferencesService.sortOrder;

    final rootPath = _browser.getRootPath();
    _currentPath = _resolveInitialPath(rootPath);
    _pathHistory
      ..clear()
      ..addAll(
        _persistedPathHistory.where((path) => path.startsWith(rootPath)),
      );

    await loadDirectory(_currentPath, addToHistory: false);
    if (_disposed) return;
    _isInitialized = true;
    notifyListeners();
    _scheduleIndex();
  }

  Future<void> loadDirectory(String path,
      {bool addToHistory = true, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    if (addToHistory && _currentPath.isNotEmpty) {
      _pathHistory.add(_currentPath);
    }

    _currentPath = path;
    _persistNavigationState();
    // Don't force refresh browser cache on initial Load to be fast.
    // Refresh command will handle browser cache invalidation.
    final items = await _browser.listDirectory(path);
    if (_disposed || _currentPath != path) return;
    _directoryItems = items;

    // Filter items based on the best available data
    final filtered = _prepareVisibleItems(items);

    _items = filtered;

    await _sortItems();
    if (_disposed || _currentPath != path) return;
    if (!silent) _isLoading = false;
    notifyListeners();

    // Watch this directory for changes
    _startWatching(path);

    // Always schedule background hydration to ensure counts are fresh
    _scheduleIndex();
  }

  List<FileItem> _prepareVisibleItems(List<FileItem> items) {
    final rootPath = _browser.getRootPath();
    final preparedItems = List<FileItem>.from(items);

    for (final item in preparedItems) {
      if (!item.isDirectory) continue;

      final indexedCount =
          _indexService.getFolderVideoCount(rootPath, item.path);
      final cachedCount = _browser.getVideoCount(item.path);
      item.videoCount = indexedCount ?? cachedCount;
    }

    if (!_showOnlyVideos) return preparedItems;

    return preparedItems.where((item) {
      if (item.isVideo) return true;
      if (item.isDirectory) {
        // Show all directories initially - let hydration hide empty ones later
        // This prevents the "no videos found" flash
        if (item.videoCount == null) return true;
        return item.videoCount! > 0;
      }
      return false;
    }).toList();
  }

  /// 同一目录树共用一个索引任务，不再逐页重复递归统计。
  void _scheduleIndex() {
    unawaited(_ensureIndex());
  }

  Future<void> _ensureIndex() async {
    try {
      await _indexService.ensureIndexed(_browser.getRootPath());
    } catch (e) {
      AppLogger.e('Library index failed', e);
      if (!_disposed) {
        _error = 'Failed to update library index: $e';
        notifyListeners();
      }
    }
  }

  void _onIndexChanged() {
    if (_disposed || _currentPath.isEmpty) return;
    final path = _currentPath;
    final revision = ++_visibilityRevision;
    final items = _prepareVisibleItems(_directoryItems);
    unawaited(sortFileItemsIsolate(items, _sortBy, _sortOrder).then((sorted) {
      if (_disposed || path != _currentPath || revision != _visibilityRevision) return;
      _items = sorted;
      notifyListeners();
    }));
  }

  Future<void> goBack() async {
    if (_pathHistory.isEmpty) return;
    final previousPath = _pathHistory.removeLast();
    _currentPath = previousPath;
    _persistNavigationState();
    final items = await _browser.listDirectory(previousPath);
    if (_disposed || _currentPath != previousPath) return;
    _directoryItems = items;
    _items = _prepareVisibleItems(items);
    await _sortItems();
    if (_disposed || _currentPath != previousPath) return;
    notifyListeners();
    _startWatching(previousPath);
    _scheduleIndex();
  }

  Future<void> navigateToFolder(FileItem folder) async {
    if (!folder.isDirectory) return;
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await loadDirectory(folder.path);
    } finally {
      _isNavigating = false;
    }
  }

  String _resolveInitialPath(String rootPath) {
    final persistedPath = _persistedCurrentPath;
    if (persistedPath == null || !persistedPath.startsWith(rootPath)) {
      return rootPath;
    }
    return persistedPath;
  }

  void _persistNavigationState() {
    _persistedCurrentPath = _currentPath;
    _persistedPathHistory = List<String>.from(_pathHistory);
  }

  void toggleShowOnlyVideos() {
    _showOnlyVideos = !_showOnlyVideos;
    unawaited(LibraryPreferencesService.setShowOnlyVideos(_showOnlyVideos));
    _browser.invalidatePath(_currentPath);
    loadDirectory(_currentPath, addToHistory: false);
  }

  void setSortBy(SortBy sortBy) {
    if (_sortBy == sortBy) {
      _sortOrder = _sortOrder == SortOrder.ascending
          ? SortOrder.descending
          : SortOrder.ascending;
    } else {
      _sortBy = sortBy;
      _sortOrder = _defaultOrderFor(sortBy);
    }
    unawaited(LibraryPreferencesService.setSortBy(_sortBy));
    unawaited(LibraryPreferencesService.setSortOrder(_sortOrder));
    _sortItems();
    notifyListeners();
  }

  SortOrder _defaultOrderFor(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.name:
        return SortOrder.ascending;
      case SortBy.date:
      case SortBy.size:
      case SortBy.videos:
        return SortOrder.descending;
    }
  }

  Future<void> _sortItems() async {
    final revision = ++_visibilityRevision;
    final sorted = await sortFileItemsIsolate(_items, _sortBy, _sortOrder);
    if (_disposed || revision != _visibilityRevision) return;
    _items = sorted;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    final rootPath = _browser.getRootPath();
    final refreshedPath = _currentPath;

    _browser.invalidatePathTree(refreshedPath);
    await loadDirectory(refreshedPath, addToHistory: false, silent: silent);
    // 目录先显示，完整索引更新通过监听分批刷新计数。
    await _indexService.refreshInBackground(rootPath);
  }

  void toggleSelection(String path) {
    if (_selectedItems.contains(path)) {
      _selectedItems.remove(path);
      if (_selectedItems.isEmpty) _isSelectionMode = false;
    } else {
      _selectedItems.add(path);
    }
    notifyListeners();
  }

  void enterSelectionMode(String initialPath) {
    _isSelectionMode = true;
    _selectedItems.add(initialPath);
    notifyListeners();
  }

  void exitSelectionMode() {
    _selectedItems.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void selectAll() {
    for (final item in _items) {
      _selectedItems.add(item.path);
    }
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final path in _selectedItems) {
      try {
        final entity = File(path);
        if (await entity.exists()) {
          await entity.delete();
        } else {
          final dir = Directory(path);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      } catch (_) {}
    }
    exitSelectionMode();
    await refresh();
  }

  bool isSelected(String path) => _selectedItems.contains(path);

  // --- File system watcher ---

  void _startWatching(String path) {
    _stopWatching();
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return;
      _dirWatcherSub = dir.watch(events: FileSystemEvent.all).listen((event) {
        // Debounce: wait 800ms of quiet before refreshing
        _watcherDebounce?.cancel();
        _watcherDebounce = Timer(const Duration(milliseconds: 800), () {
          _handleFsChange(path);
        });
      }, onError: (_) {});
    } catch (_) {
      // Watching not supported on this platform/path – fail silently
    }
  }

  void _stopWatching() {
    _watcherDebounce?.cancel();
    _watcherDebounce = null;
    _dirWatcherSub?.cancel();
    _dirWatcherSub = null;
  }

  Future<void> _handleFsChange(String watchedPath) async {
    if (_currentPath != watchedPath) return;
    // Invalidate cache for this directory and reload silently
    _browser.invalidatePath(watchedPath);
    final rootPath = _browser.getRootPath();
    // Incremental index update (fast, only scans for new/deleted files)
    await _indexService.updateIndexIncremental(rootPath, watchedPath);
    // Reload directory listing silently (no spinner)
    final items = await _browser.listDirectory(watchedPath);
    if (_disposed || _currentPath != watchedPath) return;
    _directoryItems = items;
    _items = _prepareVisibleItems(items);
    await _sortItems();
    if (_disposed || _currentPath != watchedPath) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _visibilityRevision++;
    _indexService.removeListener(_onIndexChanged);
    _stopWatching();
    super.dispose();
  }
}
