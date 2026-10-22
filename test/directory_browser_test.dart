import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mpx/features/library/data/datasources/directory_browser.dart';

void main() {
  test('批量读取大目录属性，保留视频和文件夹、过滤其他文件并正确刷新缓存', () async {
    final root = await Directory.systemTemp.createTemp('mpx_browser_');
    final browser = DirectoryBrowser();
    try {
      await Directory(p.join(root.path, 'folder')).create();
      await File(p.join(root.path, '.hidden.mp4')).writeAsString('hidden');
      await File(p.join(root.path, 'note.txt')).writeAsString('note');
      for (var i = 0; i < 40; i++) {
        await File(p.join(root.path, '$i.mp4')).writeAsString('video');
      }
      final entries = await browser.listDirectory(root.path);
      expect(entries.length, 41);
      expect(entries.first.isDirectory, isTrue);
      expect(entries.where((item) => !item.isDirectory).every((item) => item.size == 5), isTrue);
      await File(p.join(root.path, 'new.mkv')).writeAsString('new');
      expect((await browser.listDirectory(root.path)).length, 41);
      expect((await browser.listDirectory(root.path, forceRefresh: true)).length, 42);
    } finally {
      browser.invalidatePathTree(root.path);
      await root.delete(recursive: true);
    }
  });
}
