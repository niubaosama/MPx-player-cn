import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/storage_path_service.dart';
import '../../library/domain/entities/file_item.dart';
import '../../library/domain/entities/video_file.dart';
import '../../library/services/library_index_service.dart';

class ReelSource {
  final String path;
  final bool isFolder;
  final bool includeSubfolders;

  const ReelSource({required this.path, this.isFolder = true,
    this.includeSubfolders = true});

  Map<String, Object> toJson() => {'path': path, 'isFolder': isFolder,
    'includeSubfolders': includeSubfolders};

  factory ReelSource.fromJson(Map<String, dynamic> json) => ReelSource(
    path: p.normalize(json['path'] as String),
    isFolder: json['isFolder'] as bool? ?? true,
    includeSubfolders: json['includeSubfolders'] as bool? ?? true,
  );
}

/// 短视频只保存来源引用；原文件和旧版视频副本均保持原位。
class ReelService {
  static final ReelService _instance = ReelService._internal();
  factory ReelService() => _instance;
  ReelService._internal() : _index = LibraryIndexService(),
      _appDirectory = StoragePathService.getAppExternalDirectory;

  ReelService.forTesting(this._index, this._appDirectory);

  final LibraryIndexService _index;
  final Future<Directory> Function() _appDirectory;
  static const _sourcesKey = 'reels_sources_v1';
  Future<void>? _initialization;
  Future<void>? _pendingChange;

  Future<void> _initializeSources() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_sourcesKey)) return;
    final appDir = await _appDirectory();
    final candidates = <String>{p.join(appDir.path, 'mpxReels')};
    final parts = p.split(appDir.path);
    final android = parts.indexOf('Android');
    if (android > 0) {
      candidates.add(p.join(p.joinAll(parts.take(android)), 'Movies', 'mpxReels'));
    }
    final sources = <ReelSource>[];
    for (final path in candidates) {
      if (await Directory(path).exists()) sources.add(ReelSource(path: path));
    }
    await _save(sources);
  }

  Future<List<ReelSource>> getSources() async {
    await (_initialization ??= _initializeSources());
    final prefs = await SharedPreferences.getInstance();
    final rows = jsonDecode(prefs.getString(_sourcesKey) ?? '[]') as List;
    return rows.map((row) => ReelSource.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> _save(List<ReelSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_sourcesKey,
        jsonEncode(sources.map((source) => source.toJson()).toList()));
    if (!saved) throw StateError('Failed to save Reels sources');
  }

  Future<void> _change(List<ReelSource> Function(List<ReelSource>) update) async {
    final previous = _pendingChange;
    final completed = Completer<void>();
    _pendingChange = completed.future;
    try {
      if (previous != null) await previous;
      await _save(update(await getSources()));
    } finally {
      completed.complete();
      if (identical(_pendingChange, completed.future)) _pendingChange = null;
    }
  }

  Future<void> importFolder(String path, {bool includeSubfolders = true}) async {
    path = p.normalize(p.absolute(path));
    if (!await Directory(path).exists()) throw FileSystemException('Folder not found', path);
    // 校验访问权限，不复制文件，也不创建目标目录。
    await Directory(path).list(followLinks: false).take(1).drain<void>();
    final source = ReelSource(path: path, includeSubfolders: includeSubfolders);
    await _change((sources) => sources.any((item) =>
        item.path == source.path && item.isFolder) ? sources : [
      ...sources.where((item) => item.path != source.path), source,
    ]);
    await _index.ensureIndexed(path, forceRefresh: true);
  }

  Future<void> importVideoFile(String path) async {
    path = p.normalize(p.absolute(path));
    if (!await File(path).exists()) throw FileSystemException('Video not found', path);
    if (!FileItem.isVideoFileName(p.basename(path))) throw ArgumentError('Not a video file');
    final source = ReelSource(path: path, isFolder: false);
    await _change((sources) => [
      ...sources.where((item) => item.path != source.path), source,
    ]);
  }

  Future<void> removeSource(String path) =>
      _change((sources) => sources.where((item) => item.path != path).toList());

  Future<void> setIncludeSubfolders(String path, bool enabled) => _change((sources) =>
    sources.map((item) => item.path == path ? ReelSource(path: path,
        isFolder: item.isFolder, includeSubfolders: enabled) : item).toList());

  Future<List<VideoFile>> getVideosFromAnyFolder(String path,
      {bool includeSubfolders = true, bool forceRefresh = false}) =>
      _index.getVideosInFolder(path, includeSubfolders: includeSubfolders,
          forceRefresh: forceRefresh);

  Future<List<VideoFile>> getReelsVideos({bool forceRefresh = false}) async {
    final sources = await getSources();
    final videos = <String, VideoFile>{};
    // 先查询父目录，子目录来源随后可复用同一索引。
    final folders = sources.where((source) => source.isFolder).toList()
      ..sort((a, b) => a.path.length.compareTo(b.path.length));
    final refreshedRoots = <String>[];
    for (final source in folders) {
      if (!await Directory(source.path).exists()) continue;
      final refresh = forceRefresh && !refreshedRoots.any((root) =>
          root == source.path || p.isWithin(root, source.path));
      final found = await getVideosFromAnyFolder(source.path,
          includeSubfolders: source.includeSubfolders, forceRefresh: refresh);
      if (refresh) refreshedRoots.add(source.path);
      for (final video in found) { videos[video.path] = video; }
    }
    for (final source in sources.where((source) => !source.isFolder)) {
      if (videos.containsKey(source.path)) continue;
      final file = File(source.path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      videos[source.path] = VideoFile.fromFileItem(FileItem(path: source.path,
          name: p.basename(source.path), isDirectory: false, size: stat.size,
          modified: stat.modified), p.dirname(source.path));
    }
    return videos.values.toList();
  }
  Future<List<VideoFile>> getLocalVideos({bool forceRefresh = false}) async {
    final volumes = await StoragePathService.getAccessibleStorageVolumes();
    final roots = <String>{};
    for (final volume in volumes) {
      final parts = p.split(volume.path);
      final android = parts.indexOf('Android');
      roots.add(android > 0 ? p.joinAll(parts.take(android)) : volume.path);
    }
    final videos = <String, VideoFile>{};
    for (final root in roots) {
      final snapshot = await _index.ensureIndexed(root, forceRefresh: forceRefresh);
      for (final video in snapshot.videos) { videos[video.path] = video; }
    }
    return videos.values.toList();
  }

}
