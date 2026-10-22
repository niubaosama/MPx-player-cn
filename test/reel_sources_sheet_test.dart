import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/features/library/domain/entities/video_file.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/features/reels/presentation/widgets/reel_sources_sheet.dart';
import 'package:mpx/features/reels/services/reel_service.dart';

class _SourceService extends Fake implements ReelService {
  List<ReelSource> sources = [const ReelSource(path: '/videos')];
  @override
  Future<List<ReelSource>> getSources() async => List.of(sources);
  @override
  Future<List<VideoFile>> getReelsVideos({bool forceRefresh = false}) async => [];
  @override
  Future<void> removeSource(String path) async {
    sources.removeWhere((source) => source.path == path);
  }
  @override
  Future<void> setIncludeSubfolders(String path, bool enabled) async {
    sources = [ReelSource(path: path, includeSubfolders: enabled)];
  }
}

void main() {
  testWidgets('来源管理可以切换子文件夹并移除关联', (tester) async {
    final controller = ReelsController(service: _SourceService());
    await controller.loadReels();
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
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
