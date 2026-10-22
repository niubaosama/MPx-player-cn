import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/features/player/presentation/widgets/bottom_controls.dart';
import 'package:mpx/features/player/controller/utils/time_formatter.dart';

void main() {
  for (final width in [296.0, 336.0, 640.0]) {
    testWidgets('all playback controls remain usable at width $width',
        (tester) async {
      var pipPressed = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: width,
                      height: 260,
                      child: BottomControls(
                          position: const Duration(seconds: 20),
                          duration: const Duration(hours: 2),
                          isPlaying: true,
                          isFullscreen: false,
                          formatTime: formatTime,
                          onSeekStart: () {},
                          onSeekChanged: (_) {},
                          onSeekEnd: (_) {},
                          onTogglePlayPause: () {},
                          onToggleFullscreen: () {},
                          onCycleAspectRatio: () {},
                          aspectRatioLabel: 'Fit',
                          onNext: () {},
                          onPrevious: () {},
                          showPipButton: true,
                          onTogglePip: () => pipPressed = true))))));
      expect(tester.takeException(), isNull);
      expect(find.byType(IconButton), findsNWidgets(6));
      await tester.tap(find.byIcon(Icons.picture_in_picture_alt_rounded));
      await tester.pump();
      expect(pipPressed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
