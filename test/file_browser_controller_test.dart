import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/features/library/controller/file_browser_controller.dart';
import 'package:mpx/features/library/data/datasources/directory_browser.dart';
import 'package:mpx/features/library/domain/entities/file_item.dart';
import 'package:mpx/features/library/services/library_index_service.dart';
import 'package:mpx/features/library/services/library_preferences_service.dart';

class Browser extends Fake implements DirectoryBrowser {
  Completer<List<FileItem>>? pending;
  final data = [
    FileItem(
        path: '/library/a.mp4',
        name: 'a.mp4',
        isDirectory: false,
        size: 10,
        modified: DateTime(2026)),
    FileItem(
        path: '/library/b.mp4',
        name: 'b.mp4',
        isDirectory: false,
        size: 100,
        modified: DateTime(2026))
  ];
  @override
  String getRootPath() => '/library';
  @override
  Future<List<FileItem>> listDirectory(String path,
          {bool forceRefresh = false}) =>
      pending?.future ?? Future.value(List.of(data));
}

class Index extends ChangeNotifier implements LibraryIndexService {
  @override
  Future<LibraryIndexSnapshot> ensureIndexed(String rootPath,
          {bool forceRefresh = false}) async =>
      LibraryIndexSnapshot(
          videos: [], folderVideoCounts: {}, indexedAt: DateTime(2026));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LibraryPreferencesService.init();
  });
  test(
      'sorting publishes the resulting list after asynchronous sorting completes',
      () async {
    final browser = Browser();
    final index = Index();
    final controller = FileBrowserController.forTesting(browser, index);
    await controller.loadDirectory('/library');
    expect(controller.items.first.name, 'a.mp4');
    final changed = Completer<void>();
    controller.addListener(() {
      if (controller.items.first.name == 'b.mp4' && !changed.isCompleted) {
        changed.complete();
      }
    });
    controller.setSortBy(SortBy.size);
    await changed.future.timeout(const Duration(seconds: 5));
    expect(controller.items.first.size, 100);
    controller.dispose();
    index.dispose();
  });
  test(
      'a directory read finishing after disposal cannot notify or start watching',
      () async {
    final browser = Browser()..pending = Completer<List<FileItem>>();
    final index = Index();
    final controller = FileBrowserController.forTesting(browser, index);
    final loading = controller.loadDirectory('/library');
    controller.dispose();
    browser.pending!.complete(browser.data);
    await loading;
    expect(controller.items, isEmpty);
    index.dispose();
  });
}
