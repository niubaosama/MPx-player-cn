import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../settings/services/app_settings_service.dart';
import '../widgets/splash_background.dart';
import '../widgets/splash_logo.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  @override
  void initState() {
    super.initState();
    // 系统服务已在 main 中初始化，此处仅承担用户选择的视觉过渡。
    _animation = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: AppSettingsService.splashDurationMs))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decorated = AppSettingsService.splashStyle == 'decorated';
    final subtitle = AppSettingsService.splashSubtitle;
    return Scaffold(
        backgroundColor: Theme.of(context).appBackground,
        body: Stack(fit: StackFit.expand, children: [
          if (decorated) const SplashBackground(),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Spacer(),
                    FadeTransition(
                        opacity: CurvedAnimation(
                            parent: _animation, curve: const Interval(0, .5)),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (decorated) const SplashLogo(),
                          Text(AppSettingsService.splashTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(
                              subtitle.isEmpty
                                  ? context
                                      .tr('Fast video browsing, clean playback')
                                  : subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ])),
                    const Spacer(),
                    if (decorated)
                      AnimatedBuilder(
                          animation: _animation,
                          builder: (_, __) =>
                              LinearProgressIndicator(value: _animation.value)),
                  ]))),
        ]));
  }
}
