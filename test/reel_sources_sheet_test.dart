import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/features/library/services/library_index_service.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/features/reels/presentation/widgets/reel_sources_sheet.dart';
import 'package:mpx/features/reels/services/reel_service.dart';

import 'helpers/memory_index_database.dart';

void main() {
  testWidgets('来源管理可以切换子文件夹、移除关联，原文件保持不变', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('mpx_source_ui_');
    final folder = Directory(p.join(root.path, 'videos'));
    await folder.create();
    final file = await File(p.join(folder.path, 'movie.mp4')).writeAsString('original');
    final index = LibraryIndexService.forTesting(MemoryIndexDatabase());
    final service = ReelService.forTesting(index, () async => Directory(p.join(root.path, 'app')));
    final controller = ReelsController(service: service);
    await controller.loadReels();
    await controller.importFolderToReels(folder.path);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: Scaffold(body: ReelSourcesSheet(controller: controller)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('短视频来源'), findsOneWidget);
    expect(find.text('包含子文件夹'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.sources.single.includeSubfolders, isFalse);
    await tester.tap(find.byTooltip('移除来源'));
    await tester.pumpAndSettle();
    expect(find.text('尚未添加来源'), findsOneWidget);
    expect(await file.readAsString(), 'original');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    index.dispose();
    await root.delete(recursive: true);
  });
}
