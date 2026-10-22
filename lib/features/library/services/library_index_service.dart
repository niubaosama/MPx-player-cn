import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/services/logger_service.dart';
import '../domain/entities/file_item.dart';
import '../domain/entities/video_file.dart';
import '../domain/entities/video_folder.dart';

enum LibrarySearchSort { relevance, recent, name, size }

class LibraryIndexSnapshot {
  final List<VideoFile> videos;
  final Map<String, int> folderVideoCounts;
  final DateTime indexedAt;
  final bool isComplete;

  const LibraryIndexSnapshot({
    required this.videos,
    required this.folderVideoCounts,
    required this.indexedAt,
    this.isComplete = true,
  });
}

class LibraryIndexService extends ChangeNotifier {
  static final LibraryIndexService _instance = LibraryIndexService._internal();
  factory LibraryIndexService() => _instance;
  LibraryIndexService._internal() : _db = AppDatabase();

  @visibleForTesting
  LibraryIndexService.forTesting(this._db);

  final AppDatabase _db;
  final Map<String, LibraryIndexSnapshot> _snapshots = {};
  final Map<String, Future<LibraryIndexSnapshot>> _inFlight = {};

  LibraryIndexSnapshot? getSnapshot(String rootPath) => _snapshots[p.normalize(rootPath)];

  Future<bool> hasPersistedIndex(String rootPath) async =>
      await _db.readLibraryIndexCache(p.normalize(rootPath)) != null;

  int? getFolderVideoCount(String rootPath, String folderPath) {
    final snapshot = getSnapshot(rootPath);
    if (snapshot == null) return null;
    return snapshot.folderVideoCounts[p.normalize(folderPath)] ??
        (snapshot.isComplete ? 0 : null);
  }

  /// 同一路径只扫描一次；已有完整索引直接复用。
  Future<LibraryIndexSnapshot> ensureIndexed(String rootPath,
      {bool forceRefresh = false}) {
    rootPath = p.normalize(rootPath);
    final active = _inFlight[rootPath];
    if (active != null) return active;
    final snapshot = _snapshots[rootPath];
    if (!forceRefresh && snapshot != null && snapshot.isComplete) {
      return Future.value(snapshot);
    }
    final future = _loadOrBuildIndex(rootPath, forceRefresh);
    _inFlight[rootPath] = future;
    return future;
  }

  Future<LibraryIndexSnapshot> _loadOrBuildIndex(String rootPath, bool forceRefresh) async {
    var restored = false;
    try {
      if (!forceRefresh) {
        final cached = await _db.readLibraryIndexCache(rootPath);
        if (cached != null) {
          final videos = await compute(_decodeIndexVideos, cached['videos_json'] as String);
          final snapshot = _snapshot(rootPath, videos,
              DateTime.fromMillisecondsSinceEpoch(cached['indexed_at'] as int));
          _publish(rootPath, snapshot);
          restored = true;
          return snapshot;
        }
      }
      return await _buildIndex(rootPath);
    } finally {
      _inFlight.remove(rootPath);
      // 缓存先显示；变化在后台核对，不阻塞首次进入目录。
      if (restored) {
        unawaited(refreshInBackground(rootPath).catchError((Object e, StackTrace st) {
          AppLogger.e('Background library refresh failed: $rootPath', e);
        }));
      }
    }
  }

  /// 首页和文件夹来源共用索引；完整的父目录索引可直接回答子目录查询。
  Future<List<VideoFile>> getVideosInFolder(String folderPath,
      {bool includeSubfolders = true, bool forceRefresh = false}) async {
    folderPath = p.normalize(folderPath);
    LibraryIndexSnapshot? snapshot;
    if (!forceRefresh) {
      final candidates = _snapshots.entries.where((e) =>
          e.value.isComplete && (e.key == folderPath || p.isWithin(e.key, folderPath))).toList()
        ..sort((a, b) => b.value.indexedAt.compareTo(a.value.indexedAt));
      if (candidates.isNotEmpty) snapshot = candidates.first.value;
    }
    snapshot ??= await ensureIndexed(folderPath, forceRefresh: forceRefresh);
    return snapshot.videos.where((video) =>
        video.folderPath == folderPath ||
        (includeSubfolders && p.isWithin(folderPath, video.path))).toList();
  }

  Future<List<VideoFile>> search(String rootPath, String query,
      {LibrarySearchSort sortBy = LibrarySearchSort.relevance}) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];
    final snapshot = await ensureIndexed(rootPath);
    final terms = normalizedQuery.split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
    final matches = <_ScoredVideo>[];
    for (final video in snapshot.videos) {
      final score = _scoreVideo(video, normalizedQuery, terms);
      if (score > 0) matches.add(_ScoredVideo(video: video, score: score));
    }
    matches.sort((a, b) => _compareMatches(a, b, sortBy));
    return matches.map((match) => match.video).toList(growable: false);
  }

  Future<void> invalidate(String rootPath) async {
    rootPath = p.normalize(rootPath);
    while (_inFlight[rootPath] != null) {
      await _inFlight[rootPath];
    }
    _snapshots.remove(rootPath);
    await _db.removeLibraryIndexCache(rootPath);
    notifyListeners();
  }

  Future<void> refreshInBackground(String rootPath) async {
    await ensureIndexed(rootPath, forceRefresh: true);
  }

  /// 仅比较本次成功列举的目录，保留仍存在的子目录视频。
  Future<void> updateIndexIncremental(String rootPath, String dirPath) async {
    rootPath = p.normalize(rootPath);
    dirPath = p.normalize(dirPath);
    while (_inFlight[rootPath] != null) {
      await _inFlight[rootPath];
    }
    final old = _snapshots[rootPath];
    if (old == null) {
      await ensureIndexed(rootPath);
      return;
    }
    final known = {for (final v in old.videos) v.path: v};
    final direct = <String, VideoFile>{};
    final children = <String>{};
    try {
      await for (final entity in Directory(dirPath).list(followLinks: false)) {
        if (entity is Directory) {
          children.add(p.normalize(entity.path));
        } else if (entity is File && FileItem.isVideoFileName(p.basename(entity.path))) {
          final video = await _readVideo(entity, previous: known[p.normalize(entity.path)]);
          direct[video.path] = video;
        }
      }
    } on FileSystemException catch (e) {
      AppLogger.e('Cannot refresh library directory: $dirPath', e);
      return;
    }
    final videos = old.videos.where((video) {
      if (video.folderPath == dirPath) return false;
      if (!p.isWithin(dirPath, video.path)) return true;
      return children.any((child) => p.isWithin(child, video.path));
    }).toList()..addAll(direct.values);
    final snapshot = _snapshot(rootPath, videos, DateTime.now());
    _publish(rootPath, snapshot);
    // 仅更新索引和元数据；不删除原文件、历史或收藏记录。
    await _persist(rootPath, snapshot);
  }

  Future<LibraryIndexSnapshot> _buildIndex(String rootPath) async {
    final videos = <VideoFile>[];
    final previous = _snapshots[rootPath];
    final known = {for (final v in previous?.videos ?? await _db.getAllVideos()) v.path: v};
    final pending = <String>[rootPath];
    final watch = Stopwatch()..start();
    while (pending.isNotEmpty) {
      final currentPath = pending.removeLast();
      try {
        await for (final entity in Directory(currentPath).list(followLinks: false)) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') pending.add(entity.path);
          } else if (entity is File && !p.basename(entity.path).startsWith('.') &&
              FileItem.isVideoFileName(p.basename(entity.path))) {
            videos.add(await _readVideo(entity, previous: known[p.normalize(entity.path)]));
          }
          if (watch.elapsedMilliseconds >= 100) {
            // 刷新期间保留旧结果，首轮扫描则逐批展示已找到的目录。
            final visible = <String, VideoFile>{
              for (final v in previous?.videos ?? <VideoFile>[]) v.path: v,
              for (final v in videos) v.path: v,
            };
            _publish(rootPath, _snapshot(rootPath, visible.values.toList(),
                DateTime.now(), isComplete: false));
            watch.reset();
            await Future<void>.delayed(Duration.zero);
          }
        }
      } on FileSystemException catch (e) {
        AppLogger.e('Skipping inaccessible library path: $currentPath', e);
      }
    }
    final snapshot = _snapshot(rootPath, videos, DateTime.now());
    _publish(rootPath, snapshot);
    await _persist(rootPath, snapshot);
    return snapshot;
  }

  Future<VideoFile> _readVideo(File file, {VideoFile? previous}) async {
    final stat = await file.stat();
    final path = p.normalize(file.path);
    final item = FileItem(path: path, name: p.basename(path),
        isDirectory: false, size: stat.size, modified: stat.modified);
    final scanned = VideoFile.fromFileItem(item, p.dirname(path));
    if (previous == null) return scanned;
    final unchanged = previous.size == stat.size;
    return VideoFile(id: previous.id, path: path, title: scanned.title,
        folderPath: scanned.folderPath, folderName: scanned.folderName,
        size: stat.size, duration: unchanged ? previous.duration : 0,
        dateAdded: previous.dateAdded,
        width: unchanged ? previous.width : null,
        height: unchanged ? previous.height : null,
        thumbnailPath: unchanged ? previous.thumbnailPath : null);
  }

  Future<void> _persist(String rootPath, LibraryIndexSnapshot snapshot) async {
    try {
      await _db.insertVideos(snapshot.videos);
      final grouped = <String, List<VideoFile>>{};
      for (final video in snapshot.videos) {
        grouped.putIfAbsent(video.folderPath, () => []).add(video);
      }
      await _db.insertFolders(grouped.entries.map((e) => VideoFolder(
          path: e.key, name: p.basename(e.key), videos: e.value)).toList());
      final json = await compute(_encodeIndexVideos, snapshot.videos);
      await _db.writeLibraryIndexCache(rootPath, json, snapshot.indexedAt);
    } catch (e) {
      AppLogger.e('Failed to persist library index: $rootPath', e);
      rethrow;
    }
  }

  LibraryIndexSnapshot _snapshot(String rootPath, List<VideoFile> videos,
      DateTime indexedAt, {bool isComplete = true}) {
    final counts = <String, int>{};
    for (final video in videos) {
      var folder = video.folderPath;
      while (folder == rootPath || p.isWithin(rootPath, folder)) {
        counts[folder] = (counts[folder] ?? 0) + 1;
        if (folder == rootPath) break;
        folder = p.dirname(folder);
      }
    }
    return LibraryIndexSnapshot(videos: List.unmodifiable(videos),
        folderVideoCounts: Map.unmodifiable(counts), indexedAt: indexedAt,
        isComplete: isComplete);
  }

  void _publish(String rootPath, LibraryIndexSnapshot snapshot) {
    _snapshots[rootPath] = snapshot;
    if (snapshot.isComplete) {
      for (final entry in _snapshots.entries.toList()) {
        if (entry.value.isComplete && p.isWithin(entry.key, rootPath)) {
          final merged = entry.value.videos.where((v) => !p.isWithin(rootPath, v.path)).toList()
            ..addAll(snapshot.videos);
          _snapshots[entry.key] = _snapshot(entry.key, merged, snapshot.indexedAt);
        }
      }
    }
    notifyListeners();
  }

  int _scoreVideo(VideoFile video, String query, List<String> terms) {
    final title = video.title.toLowerCase();
    final folderName = video.folderName.toLowerCase();

    int? titleScore = _fuzzyScore(title, query, terms);
    if (titleScore == null) return 0;

    var score = titleScore;

    if (folderName.contains(query)) score += 180;
    if (title == query) score += 1200;
    if (title.startsWith(query)) score += 800;
    if (title.contains(query)) score += 500;

    for (final term in terms) {
      if (title.startsWith(term)) {
        score += 180;
      } else if (title.contains(term)) {
        score += 120;
      }

      if (folderName.contains(term)) {
        score += 60;
      }
    }

    final age = DateTime.now().difference(video.dateAdded);
    if (age.inDays <= 7) {
      score += 90;
    } else if (age.inDays <= 30) {
      score += 45;
    } else if (age.inDays <= 90) {
      score += 20;
    }

    return score;
  }

  int? _fuzzyScore(String target, String query, List<String> terms) {
    final exactScore = _exactMatchScore(target, query, terms);
    if (exactScore != null) return exactScore;

    final fuzzyScore = _fuzzyMatchScore(target, query);
    if (fuzzyScore > 0) return fuzzyScore;

    return null;
  }

  int? _exactMatchScore(String target, String query, List<String> terms) {
    if (target == query) return 1000;
    if (target.startsWith(query)) return 800;
    if (target.contains(query)) return 500;

    if (terms.every((term) => target.contains(term))) {
      var score = 300;
      for (final term in terms) {
        if (target.contains(term)) score += 50;
      }
      return score;
    }

    return null;
  }

  int _fuzzyMatchScore(String target, String query) {
    if (query.isEmpty || target.isEmpty) return 0;

    int bestScore = 0;

    for (int start = 0; start < target.length; start++) {
      int score = 0;
      int queryIndex = 0;
      int targetIndex = start;
      bool lastMatchWasConsecutive = false;
      bool firstMatch = true;

      while (queryIndex < query.length && targetIndex < target.length) {
        if (target[targetIndex] == query[queryIndex]) {
          if (firstMatch) {
            score += 10;
            firstMatch = false;
          } else if (lastMatchWasConsecutive) {
            score += 15;
          } else {
            score += 5;
          }

          if (targetIndex > 0 && target[targetIndex - 1] == ' ') {
            score += 20;
          }

          queryIndex++;
          lastMatchWasConsecutive = true;
        } else {
          lastMatchWasConsecutive = false;
        }
        targetIndex++;
      }

      if (queryIndex == query.length && score > bestScore) {
        bestScore = score;
      }
    }

    if (bestScore >= query.length * 5) {
      return bestScore;
    }

    return 0;
  }

  int _compareMatches(
    _ScoredVideo a,
    _ScoredVideo b,
    LibrarySearchSort sortBy,
  ) {
    switch (sortBy) {
      case LibrarySearchSort.relevance:
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        final dateCompare = b.video.dateAdded.compareTo(a.video.dateAdded);
        if (dateCompare != 0) return dateCompare;
        return a.video.title
            .toLowerCase()
            .compareTo(b.video.title.toLowerCase());
      case LibrarySearchSort.recent:
        final dateCompare = b.video.dateAdded.compareTo(a.video.dateAdded);
        if (dateCompare != 0) return dateCompare;
        return a.video.title
            .toLowerCase()
            .compareTo(b.video.title.toLowerCase());
      case LibrarySearchSort.name:
        return a.video.title
            .toLowerCase()
            .compareTo(b.video.title.toLowerCase());
      case LibrarySearchSort.size:
        final sizeCompare = b.video.size.compareTo(a.video.size);
        if (sizeCompare != 0) return sizeCompare;
        return a.video.title
            .toLowerCase()
            .compareTo(b.video.title.toLowerCase());
    }
  }


}

class _ScoredVideo {
  final VideoFile video;
  final int score;

  const _ScoredVideo({required this.video, required this.score});
}

List<VideoFile> _decodeIndexVideos(String value) => (jsonDecode(value) as List)
    .map((row) => VideoFile.fromJson(Map<String, dynamic>.from(row as Map))).toList();

String _encodeIndexVideos(List<VideoFile> videos) =>
    jsonEncode(videos.map((video) => video.toJson()).toList());
