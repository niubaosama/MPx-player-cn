import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/features/downloader/data/models/video_info_model.dart';
import 'package:mpx/features/settings/controllers/app_settings_controller.dart';
import 'package:mpx/features/settings/presentation/screens/settings_screen.dart';
import 'package:mpx/features/settings/services/app_settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('缺失视频标题保持空值，真实英文标题不作为界面文案翻译', () {
    expect(VideoInfoModel.fromJson({}).title, isEmpty);
    expect(VideoInfoModel.fromJson({'title': 'Untitled'}).title, 'Untitled');
    expect(VideoInfoModel.fromJson({'title': 'Settings'}).title, 'Settings');
  });

  test('中英文资源、插值和相对时间', () {
    const zh = AppLocalizations(Locale('zh'));
    const en = AppLocalizations(Locale('en'));
    expect(zh.text('Settings'), '设置');
    expect(en.text('Settings'), 'Settings');
    expect(zh.text('Track {value0}', {'value0': 2}), '音轨 2');
    // 用户文件名中的占位符字符应原样保留，不能再次被替换。
    expect(
      zh.text('Subtitle loaded: {value0}', {
        'value0': '字幕{value1}.srt',
        'value1': '不可替换',
      }),
      '已加载字幕：字幕{value1}.srt',
    );
    expect(zh.text('My video.mp4'), 'My video.mp4');
    final now = DateTime(2026, 10, 22, 12);
    expect(
      zh.relativeDate(now.subtract(const Duration(minutes: 5)), now: now),
      '5 分钟前',
    );
    expect(
      en.relativeDate(now.subtract(const Duration(days: 1)), now: now),
      'Yesterday',
    );
  });

  test('语言选择持久化，跟随系统不指定固定区域', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.init();
    final settings = AppSettingsController();
    expect(settings.language, AppLanguage.system);
    expect(settings.locale, isNull);
    expect(await settings.setLanguage(AppLanguage.zh), isTrue);
    expect(settings.locale, const Locale('zh'));
    await AppSettingsService.init();
    final restored = AppSettingsController();
    expect(restored.language, AppLanguage.zh);
    await restored.setLanguage(AppLanguage.en);
    expect(restored.locale, const Locale('en'));
    await restored.setLanguage(AppLanguage.system);
    expect(restored.locale, isNull);
    settings.dispose();
    restored.dispose();
  });

  testWidgets('设置页切换语言后，已有的常量子组件也立即更新', (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.app_language': 'en'});
    await AppSettingsService.init();
    final settings = AppSettingsController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: Consumer<AppSettingsController>(
          builder: (context, settings, _) => MaterialApp(
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<AppLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(settings.language, AppLanguage.zh);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'zh');
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });

  testWidgets('跟随系统时响应系统语言变化，不支持的语言回退英文', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: _LocalizedLabel(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}

class _LocalizedLabel extends StatelessWidget {
  const _LocalizedLabel();

  @override
  Widget build(BuildContext context) => Text(context.tr('Settings'));
}
