import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mpx/features/library/services/library_index_service.dart';

import 'helpers/memory_index_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late MemoryIndexDatabase database;
  late LibraryIndexService index;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mpx_index_');
    database = MemoryIndexDatabase();
    index = LibraryIndexService.forTesting(database);
  });
  tearDown(() async {
    index.dispose();
    await root.delete(recursive: true);
  });

  Future<File> video(String name) async {
    final file = File(p.join(root.path, name));
    await file.parent.create(recursive: true);
    return file.writeAsString('test-video');
  }

  test('深层目录计数完整，隐藏目录和 Android 目录不加入公共索引', () async {
    final deep = await video('a/b/c/d/movie.mp4');
    await video('.hidden/private.mp4');
    await video('Android/data/private.mp4');
    final snapshot = await index.ensureIndexed(root.path);
    expect(snapshot.videos.map((v) => v.path), [deep.path]);
    expect(index.getFolderVideoCount(root.path, p.join(root.path, 'a')), 1);
    expect(index.getFolderVideoCount(root.path, p.join(root.path, 'empty')), 0);
  });

  test('并发请求只建一次索引，子目录查询复用父目录快照', () async {
    await video('a/movie.mp4');
    final first = index.ensureIndexed(root.path);
    final second = index.ensureIndexed(root.path);
    expect(identical(first, second), isTrue);
    await first;
    await index.getVideosInFolder(p.join(root.path, 'a'));
    expect(database.writes, 1);
  });

  test('父目录增量刷新保留仍存在的子目录视频，只移除已消失的索引条目', () async {
    final direct = await video('direct.mp4');
    final child = await video('child/nested.mp4');
    await index.ensureIndexed(root.path);
    await direct.delete();
    await index.updateIndexIncremental(root.path, root.path);
    expect(index.getSnapshot(root.path)!.videos.map((v) => v.path), [child.path]);
    expect(await child.readAsString(), 'test-video');
    expect(index.getFolderVideoCount(root.path, root.path), 1);
  });

  test('删除子目录后更新索引，不影响其他视频文件', () async {
    await video('removed/a.mp4');
    final kept = await video('kept/b.mp4');
    await index.ensureIndexed(root.path);
    await Directory(p.join(root.path, 'removed')).delete(recursive: true);
    await index.updateIndexIncremental(root.path, root.path);
    expect(index.getSnapshot(root.path)!.videos.single.path, kept.path);
    expect(await kept.exists(), isTrue);
  });

  test('空目录也可从缓存恢复，不在每次查询时重新扫描', () async {
    await index.ensureIndexed(root.path);
    final writes = database.writes;
    await index.ensureIndexed(root.path);
    expect(database.writes, writes);
    expect(await index.hasPersistedIndex(root.path), isTrue);
  });

  test('重启服务先读取缓存，后台扫描完成后发布新结果', () async {
    final old = await video('old.mp4');
    await index.ensureIndexed(root.path);
    final fresh = await video('new.mp4');
    final restored = LibraryIndexService.forTesting(database);
    final cached = await restored.ensureIndexed(root.path);
    expect(cached.videos.map((v) => v.path), [old.path]);
    await restored.refreshInBackground(root.path);
    expect(restored.getSnapshot(root.path)!.videos.map((v) => v.path),
        unorderedEquals([old.path, fresh.path]));
    restored.dispose();
  });

  test('非递归查询只返回当前目录，路径相似的兄弟目录不混入', () async {
    final direct = await video('folder/a.mp4');
    await video('folder/child/b.mp4');
    await video('folder-other/c.mp4');
    await index.ensureIndexed(root.path);
    final found = await index.getVideosInFolder(p.join(root.path, 'folder'), includeSubfolders: false);
    expect(found.map((v) => v.path), [direct.path]);
  });
}
