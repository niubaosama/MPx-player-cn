import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/features/library/services/library_index_service.dart';
import 'package:mpx/features/reels/services/reel_service.dart';

import 'helpers/memory_index_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LibraryIndexService index;
  late ReelService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('mpx_sources_');
    index = LibraryIndexService.forTesting(MemoryIndexDatabase());
    service = ReelService.forTesting(index, () async => Directory(p.join(root.path, 'app')));
  });
  tearDown(() async {
    index.dispose();
    await root.delete(recursive: true);
  });

  Future<File> video(String name, [String contents = 'original-video']) async {
    final file = File(p.join(root.path, name));
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  test('添加多个文件夹不复制视频，同名文件分别保留', () async {
    final first = await video('one/same.mp4', 'first');
    final second = await video('two/same.mp4', 'second');
    await service.importFolder(first.parent.path);
    await service.importFolder(second.parent.path);
    final videos = await service.getReelsVideos();
    expect(videos.map((v) => v.path), unorderedEquals([first.path, second.path]));
    expect(videos.map((v) => v.id).toSet().length, 2);
    expect(await first.readAsString(), 'first');
    expect(await second.readAsString(), 'second');
    final files = await root.list(recursive: true).where((e) => e is File).toList();
    expect(files.length, 2);
    expect(await Directory(p.join(root.path, 'app', 'mpxReels')).exists(), isFalse);
  });

  test('父子来源和单文件来源重叠时按路径去重', () async {
    final file = await video('parent/child/movie.mp4');
    await service.importFolder(p.join(root.path, 'parent'));
    await service.importFolder(file.parent.path);
    await service.importVideoFile(file.path);
    expect((await service.getReelsVideos()).single.path, file.path);
  });

  test('可关闭子文件夹，移除来源不删除原视频', () async {
    final direct = await video('parent/direct.mp4');
    final nested = await video('parent/child/nested.mp4');
    await service.importFolder(direct.parent.path, includeSubfolders: false);
    expect((await service.getReelsVideos()).single.path, direct.path);
    await service.setIncludeSubfolders(direct.parent.path, true);
    expect((await service.getReelsVideos()).length, 2);
    await service.removeSource(direct.parent.path);
    expect(await service.getReelsVideos(), isEmpty);
    expect(await direct.exists(), isTrue);
    expect(await nested.exists(), isTrue);
  });

  test('来源持久化且并发添加不丢失，重复添加不产生副本', () async {
    final first = await video('one/a.mp4');
    final second = await video('two/b.mp4');
    await Future.wait([service.importFolder(first.parent.path), service.importFolder(second.parent.path)]);
    await service.importFolder(first.parent.path);
    final restored = ReelService.forTesting(index, () async => Directory(p.join(root.path, 'app')));
    expect((await restored.getSources()).map((s) => s.path),
        unorderedEquals([first.parent.path, second.parent.path]));
  });

  test('旧公共目录和应用目录均接续读取，移除后不再次自动添加', () async {
    final app = Directory(p.join(root.path, 'Android', 'data', 'mpx', 'files'));
    final oldApp = await video(p.join(p.relative(app.path, from: root.path), 'mpxReels', 'old.mp4'));
    final oldPublic = await video('Movies/mpxReels/old.mp4');
    final legacy = ReelService.forTesting(index, () async => app);
    final sources = await legacy.getSources();
    expect(sources.map((s) => s.path), unorderedEquals([oldApp.parent.path, oldPublic.parent.path]));
    expect((await legacy.getReelsVideos()).length, 2);
    await legacy.removeSource(oldPublic.parent.path);
    final reopened = ReelService.forTesting(index, () async => app);
    expect((await reopened.getSources()).length, 1);
    expect(await oldPublic.exists(), isTrue);
  });

  test('已不存在的来源可保留并移除，不阻断其他有效来源', () async {
    final old = await video('gone/old.mp4');
    final kept = await video('kept/new.mp4');
    await service.importFolder(old.parent.path);
    await service.importFolder(kept.parent.path);
    await old.parent.delete(recursive: true);
    expect((await service.getReelsVideos()).single.path, kept.path);
    expect((await service.getSources()).length, 2);
  });

  test('无效路径报错，不记录伪来源、不创建目录', () async {
    await expectLater(service.importFolder(p.join(root.path, 'missing')), throwsA(isA<FileSystemException>()));
    expect(await service.getSources(), isEmpty);
    expect(await Directory(p.join(root.path, 'missing')).exists(), isFalse);
  });

  test('已有父目录缓存后添加新来源，能看到新增视频并更新父目录计数', () async {
    await index.ensureIndexed(root.path);
    final fresh = await video('new-folder/new.mp4');
    await service.importFolder(fresh.parent.path);
    expect((await service.getReelsVideos()).single.path, fresh.path);
    expect(index.getFolderVideoCount(root.path, root.path), 1);
  });
}
