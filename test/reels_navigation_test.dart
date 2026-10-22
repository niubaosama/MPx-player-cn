import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mpx/features/library/domain/entities/video_file.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/features/reels/presentation/screens/reels_screen.dart';

class Probe extends StatefulWidget {
  final String path;
  final ValueChanged<int> onChange;
  const Probe({super.key, required this.path, required this.onChange});
  @override
  State<Probe> createState() => _ProbeState();
}
class _ProbeState extends State<Probe> {
  @override
  void initState() { super.initState(); widget.onChange(1); }
  @override
  void dispose() { widget.onChange(-1); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: Text(widget.path));
}
void main() {
  testWidgets('tab changes and route replacement keep one visible player and restore the session', (tester) async {
    final videos = List.generate(3, (i) => VideoFile(id: '$i', path: '/videos/$i.mp4',
      title: '$i.mp4', folderPath: '/videos', folderName: 'videos', size: 10,
      duration: 100000, dateAdded: DateTime(2026, 1, i + 1)));
    final controller = ReelsController(initialVideos: videos, initialVideoPath: videos[1].path,
      initialPosition: const Duration(seconds: 40), initialSpeed: 1.5, initiallyPaused: true);
    final active = ValueNotifier(true);
    final navigator = GlobalKey<NavigatorState>();
    var livePlayers = 0;
    var peakPlayers = 0;
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
      home: ChangeNotifierProvider.value(value: controller, child: ValueListenableBuilder<bool>(
        valueListenable: active, builder: (_, value, __) => ReelsScreen(isActive: value,
          playerBuilder: (_, video, session) => Probe(key: ValueKey(video.path), path: video.path,
            onChange: (delta) { livePlayers += delta; if (livePlayers > peakPlayers) peakPlayers = livePlayers; }))))));
    await tester.pumpAndSettle();
    expect(livePlayers, 1);
    expect(find.text(videos[1].path), findsOneWidget);
    controller.rememberPosition(videos[1].path, const Duration(seconds: 74));
    controller.toggleMute();
    active.value = false;
    await tester.pumpAndSettle();
    expect(livePlayers, 0);
    active.value = true;
    await tester.pumpAndSettle();
    expect(livePlayers, 1);
    expect(controller.currentIndex, 1);
    expect(controller.positionFor(videos[1].path), const Duration(seconds: 74));
    expect(controller.isPaused, isTrue);
    expect(controller.isMuted, isTrue);
    expect(controller.playbackSpeed, 1.5);
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('other route'))));
    await tester.pumpAndSettle();
    expect(livePlayers, 0);
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('replacement route'))));
    await tester.pumpAndSettle();
    expect(livePlayers, 0);
    controller.selectVideo(videos[2].path, const Duration(seconds: 99), 1.25, false);
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(livePlayers, 1);
    expect(find.text(videos[2].path), findsOneWidget);
    expect(controller.positionFor(videos[2].path), const Duration(seconds: 99));
    expect(peakPlayers, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    active.dispose();
    expect(livePlayers, 0);
  });
}
