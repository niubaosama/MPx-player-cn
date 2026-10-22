import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/features/reels/services/reel_service.dart';
import 'package:mpx/features/library/domain/entities/video_file.dart';

VideoFile video(String name, int date) => VideoFile(id: name, path: '/videos/$name.mp4',
  title: name, folderPath: '/videos', folderName: 'videos', size: 100, duration: 600000,
  dateAdded: DateTime(2026, 1, date));
class SessionService extends Fake implements ReelService {
  List<VideoFile> folders = [video('a', 1), video('b', 2), video('c', 3)];
  List<VideoFile> local = [video('x', 4), video('y', 5), video('z', 6)];
  @override
  Future<List<ReelSource>> getSources() async => [];
  @override
  Future<List<VideoFile>> getReelsVideos({bool forceRefresh = false}) async => List.of(folders);
  @override
  Future<List<VideoFile>> getLocalVideos({bool forceRefresh = false}) async => List.of(local);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('refresh and sorting retain current video and playback position', () async {
    final service = SessionService();
    final controller = ReelsController(service: service);
    await controller.initialized;
    controller.selectIndex(1);
    final path = controller.currentVideo!.path;
    controller.rememberPosition(path, const Duration(seconds: 123));
    controller.setPaused(true);
    controller.toggleMute();
    controller.setPlaybackSpeed(1.5);
    controller.changeSortOrder(ReelsSortOrder.nameAsc);
    expect(controller.currentVideo!.path, path);
    service.folders = [video('new', 7), ...service.folders];
    await controller.loadReels(forceRefresh: true);
    expect(controller.currentVideo!.path, path);
    expect(controller.positionFor(path), const Duration(seconds: 123));
    expect(controller.isPaused, isTrue);
    expect(controller.isMuted, isTrue);
    expect(controller.playbackSpeed, 1.5);
    controller.dispose();
  });
  test('random queue survives mode changes without reshuffling or losing position', () async {
    final controller = ReelsController(service: SessionService());
    await controller.initialized;
    await controller.setSourceMode(ReelsSourceMode.localRandom);
    final order = controller.reelsVideos.map((video) => video.path).toList();
    controller.selectIndex(2);
    final path = controller.currentVideo!.path;
    controller.rememberPosition(path, const Duration(seconds: 70));
    await controller.setSourceMode(ReelsSourceMode.folders);
    await controller.setSourceMode(ReelsSourceMode.localRandom);
    expect(controller.reelsVideos.map((video) => video.path), order);
    expect(controller.currentIndex, 2);
    expect(controller.currentVideo!.path, path);
    expect(controller.positionFor(path), const Duration(seconds: 70));
    await controller.loadReels();
    expect(controller.reelsVideos.map((video) => video.path), order);
    controller.dispose();
  });
  test('normal player handoff keeps supplied queue order, index and playback intent', () async {
    final videos = [video('b', 2), video('a', 1)];
    final controller = ReelsController(service: SessionService(), initialVideos: videos,
      initialVideoPath: videos[1].path, initialPosition: const Duration(seconds: 80),
      initialSpeed: 1.25, initiallyPaused: true);
    await controller.initialized;
    expect(controller.reelsVideos.map((video) => video.id), ['b', 'a']);
    expect(controller.currentIndex, 1);
    expect(controller.positionFor(videos[1].path), const Duration(seconds: 80));
    expect(controller.playbackSpeed, 1.25);
    expect(controller.isPaused, isTrue);
    controller.dispose();
  });
  test('missing current video falls back safely while retaining remaining queue', () async {
    final service = SessionService();
    final controller = ReelsController(service: service);
    await controller.initialized;
    controller.selectIndex(1);
    service.folders.removeWhere((video) => video.path == controller.currentVideo!.path);
    await controller.loadReels(forceRefresh: true);
    expect(controller.currentIndex, 0);
    expect(controller.reelsVideos.length, 2);
    expect(controller.currentVideo, isNotNull);
    controller.dispose();
  });
  test('source mode restores from preferences', () async {
    SharedPreferences.setMockInitialValues({'reels_source_mode': 'localRandom'});
    final controller = ReelsController(service: SessionService());
    await controller.initialized;
    expect(controller.sourceMode, ReelsSourceMode.localRandom);
    expect(controller.reelsVideos.every((video) => ['x','y','z'].contains(video.id)), isTrue);
    controller.dispose();
  });
}
