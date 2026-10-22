import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/features/player/presentation/widgets/playback_seek_bar.dart';
import 'package:mpx/features/player/controller/utils/time_formatter.dart';
void main() {
  testWidgets('seek preview does not commit until release and has a 48px hit area', (tester) async {
    var starts = 0;
    var commits = 0;
    double? preview;
    double? finalValue;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 320,
      child: PlaybackSeekBar(position: const Duration(seconds: 10), duration: const Duration(seconds: 100),
        onSeekStart: () => starts++, onSeekChanged: (value) => preview = value,
        onSeekEnd: (value) { commits++; finalValue = value; }))))));
    expect(tester.getSize(find.byType(PlaybackSeekBar)).height, 48);
    final rect = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(Offset(rect.left + 80, rect.center.dy));
    await gesture.moveBy(const Offset(110, 0));
    await tester.pump();
    expect(starts, 1);
    expect(preview, isNotNull);
    expect(commits, 0);
    await gesture.up();
    await tester.pump();
    expect(commits, 1);
    expect(finalValue, inInclusiveRange(0, 100000));
  });
  testWidgets('unknown duration disables seeking', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlaybackSeekBar(position: Duration.zero,
      duration: Duration.zero, onSeekStart: () => fail('disabled'),
      onSeekChanged: (_) => fail('disabled'), onSeekEnd: (_) => fail('disabled')))));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });
  test('long videos retain hours in the shared time format', () {
    expect(formatTime(const Duration(hours: 2, minutes: 3, seconds: 4)), '02:03:04');
  });
}
