import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/core/database/app_database.dart';
import 'package:mpx/features/library/domain/entities/video_file.dart';
import 'package:mpx/features/library/domain/entities/video_folder.dart';

/// 测试使用真实文件系统扫描，只替换需要手机 SQLite 插件的持久化边界。
class MemoryIndexDatabase extends Fake implements AppDatabase {
  final Map<String, Map<String, dynamic>> caches = {};
  int writes = 0;

  @override
  Future<List<VideoFile>> getAllVideos() async => [];

  @override
  Future<Map<String, dynamic>?> readLibraryIndexCache(String rootPath) async => caches[rootPath];

  @override
  Future<void> writeLibraryIndexCache(String rootPath, String videosJson, DateTime indexedAt) async {
    caches[rootPath] = {'videos_json': videosJson, 'indexed_at': indexedAt.millisecondsSinceEpoch};
    writes++;
  }

  @override
  Future<void> removeLibraryIndexCache(String rootPath) async { caches.remove(rootPath); }

  @override
  Future<void> insertVideos(List<VideoFile> videos) async {}

  @override
  Future<void> insertFolders(List<VideoFolder> folders) async {}
}
