import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/features/settings/services/app_settings_service.dart';
import 'package:mpx/features/splash/presentation/screens/splash_screen.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { SharedPreferences.setMockInitialValues({}); await AppSettingsService.init(); });
  test('startup preferences persist with bounded display duration', () async {
    await AppSettingsService.saveSplashSettings(enabled: false, durationMs: 20,
      style: 'minimal', title: '我的播放器', subtitle: '随心播放');
    await AppSettingsService.init();
    expect(AppSettingsService.splashEnabled, isFalse);
    expect(AppSettingsService.splashDurationMs, 200);
    expect(AppSettingsService.splashTitle, '我的播放器');
    expect(AppSettingsService.splashSubtitle, '随心播放');
  });
  testWidgets('splash completes at configured duration without extra waiting', (tester) async {
    await AppSettingsService.saveSplashSettings(enabled: true, durationMs: 400,
      style: 'minimal', title: '自定义标题', subtitle: '自定义副标题');
    var completed = 0;
    await tester.pumpWidget(MaterialApp(home: SplashScreen(onComplete: () => completed++)));
    expect(find.text('自定义标题'), findsOneWidget);
    expect(find.text('自定义副标题'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 399));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 17));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
  });
}
