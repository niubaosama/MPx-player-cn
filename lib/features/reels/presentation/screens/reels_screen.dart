import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../player/domain/entities/playback_transfer.dart';
import '../../../library/domain/entities/video_file.dart';
import '../../../player/presentation/screens/video_player_screen.dart';
import '../../controllers/reels_controller.dart';
import '../widgets/reel_player_item.dart';
import '../widgets/reel_sources_sheet.dart';
import '../widgets/reels_sort_menu.dart';

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  final String? folderPath;
  final PlaybackTransfer? initialPlayback;
  final ValueChanged<PlaybackTransfer>? onPlaybackChanged;
  final Widget Function(BuildContext, VideoFile, ReelsController)?
      playerBuilder;
  const ReelsScreen(
      {super.key,
      this.isActive = true,
      this.folderPath,
      this.initialPlayback,
      this.onPlaybackChanged,
      this.playerBuilder});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.folderPath != null || widget.initialPlayback != null) {
      final playback = widget.initialPlayback;
      return ChangeNotifierProvider(
          create: (_) => ReelsController(
              targetFolderPath: widget.folderPath,
              initialVideos: playback?.videos,
              initialVideoPath: playback?.video.path,
              initialPosition: playback?.position ?? Duration.zero,
              initialSpeed: playback?.speed ?? 1,
              initiallyPaused: playback?.paused ?? false),
          child: _ReelsContent(
              isActive: true,
              standalone: true,
              onPlaybackChanged: widget.onPlaybackChanged,
              playerBuilder: widget.playerBuilder));
    }
    return _ReelsContent(
        isActive: widget.isActive,
        standalone: false,
        playerBuilder: widget.playerBuilder);
  }
}

class _ReelsContent extends StatefulWidget {
  final bool isActive;
  final bool standalone;
  final ValueChanged<PlaybackTransfer>? onPlaybackChanged;
  final Widget Function(BuildContext, VideoFile, ReelsController)?
      playerBuilder;
  const _ReelsContent(
      {required this.isActive,
      required this.standalone,
      this.onPlaybackChanged,
      this.playerBuilder});
  @override
  State<_ReelsContent> createState() => _ReelsContentState();
}

class _ReelsContentState extends State<_ReelsContent>
    with WidgetsBindingObserver {
  PageController? _pages;
  int _revision = -1;
  bool _appActive = true;
  bool _routeCovered = false;
  bool get _active =>
      widget.isActive &&
      _appActive &&
      !_routeCovered &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _appActive = state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages?.dispose();
    super.dispose();
  }

  PlaybackTransfer? _transfer(ReelsController controller) =>
      controller.currentVideo == null
          ? null
          : PlaybackTransfer(
              videos: List.of(controller.reelsVideos),
              index: controller.currentIndex,
              position: controller.positionFor(controller.currentVideo!.path),
              speed: controller.playbackSpeed,
              paused: controller.isPaused);
  Future<void> _openNormal(ReelsController controller) async {
    final playback = _transfer(controller);
    if (playback == null) {
      return;
    }
    final route = MaterialPageRoute<PlaybackTransfer>(
        builder: (_) => VideoPlayerScreen(
            video: playback.video,
            playlist: playback.videos,
            initialPlaylistIndex: playback.index,
            initialPosition: playback.position,
            initialPlaybackSpeed: playback.speed,
            initiallyPaused: playback.paused,
            returnPlaybackState: !widget.standalone,
            onPlaybackChanged: widget.standalone
                ? widget.onPlaybackChanged
                : (result) {
                    if (mounted) {
                      controller.selectVideo(result.video.path, result.position,
                          result.speed, result.paused);
                    }
                  }));
    if (widget.standalone) {
      widget.onPlaybackChanged?.call(playback);
      Navigator.of(context).pushReplacement(route);
    } else {
      setState(() => _routeCovered = true);
      await Navigator.of(context).push(route);
      if (!mounted) {
        return;
      }
      setState(() => _routeCovered = false);
    }
  }

  void _leave(ReelsController controller) {
    final playback = _transfer(controller);
    if (playback != null) {
      widget.onPlaybackChanged?.call(playback);
    }
    Navigator.of(context).pop(playback);
  }

  Future<void> _sources(ReelsController controller) async {
    setState(() => _routeCovered = true);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85),
            child: ReelSourcesSheet(controller: controller)));
    if (mounted) {
      setState(() => _routeCovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReelsController>();
    if (_pages == null || _revision != controller.queueRevision) {
      final previous = _pages;
      _pages = PageController(initialPage: controller.currentIndex);
      _revision = controller.queueRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    }
    return PopScope<PlaybackTransfer>(
        canPop: !widget.standalone,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && widget.standalone) {
            _leave(controller);
          }
        },
        child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(children: [
              if (controller.reelsVideos.isNotEmpty)
                PageView.builder(
                    key: ValueKey(controller.queueRevision),
                    controller: _pages,
                    scrollDirection: Axis.vertical,
                    onPageChanged: controller.selectIndex,
                    itemCount: controller.reelsVideos.length,
                    itemBuilder: (context, index) {
                      final video = controller.reelsVideos[index];
                      if (!_active || index != controller.currentIndex) {
                        return const SizedBox.expand();
                      }
                      final playerBuilder = widget.playerBuilder;
                      if (playerBuilder != null) {
                        return playerBuilder(context, video, controller);
                      }
                      return ReelPlayerItem(
                          key: ValueKey(video.path),
                          video: video,
                          initialPosition: controller.positionFor(video.path),
                          playbackSpeed: controller.playbackSpeed,
                          isPaused: controller.isPaused,
                          isMuted: controller.isMuted,
                          onTogglePause: controller.togglePause,
                          onPosition: (position) => controller.rememberPosition(
                              video.path, position));
                    }),
              if (controller.reelsVideos.isEmpty)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (controller.isLoading)
                            const CircularProgressIndicator()
                          else ...[
                            Text(
                                controller.error == null
                                    ? context.tr('No videos available')
                                    : context.tr('Unable to load videos'),
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 12),
                            if (!widget.standalone)
                              FilledButton.icon(
                                  onPressed: () => _sources(controller),
                                  icon: const Icon(Icons.folder_open),
                                  label: Text(context.tr('Manage sources'))),
                            TextButton(
                                onPressed: () =>
                                    controller.loadReels(forceRefresh: true),
                                child: Text(context.tr('Refresh'))),
                          ],
                        ]))),
              SafeArea(
                  bottom: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(children: [
                        if (widget.standalone)
                          IconButton(
                              onPressed: () => _leave(controller),
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white))
                        else
                          PopupMenuButton<Object>(
                              initialValue: controller.sourceMode,
                              enabled: !controller.isLoading,
                              tooltip: context.tr('Video source'),
                              onSelected: (value) {
                                if (value is ReelsSourceMode) {
                                  controller.setSourceMode(value);
                                }
                                if (value == 'sources') {
                                  _sources(controller);
                                }
                              },
                              icon: const Icon(Icons.video_library_outlined,
                                  color: Colors.white),
                              itemBuilder: (_) => [
                                    PopupMenuItem(
                                        value: ReelsSourceMode.folders,
                                        child:
                                            Text(context.tr('Folder sources'))),
                                    PopupMenuItem(
                                        value: ReelsSourceMode.localRandom,
                                        child: Text(
                                            context.tr('Random local videos'))),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                        value: 'sources',
                                        child:
                                            Text(context.tr('Manage sources'))),
                                  ]),
                        if (!widget.standalone)
                          Expanded(
                              child: Text(
                                  context.tr(controller.sourceMode ==
                                          ReelsSourceMode.localRandom
                                      ? 'Random local videos'
                                      : 'Folder sources'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(color: Colors.white70))),
                        if (widget.standalone) const Spacer(),
                        IconButton(
                            tooltip: context.tr('Normal playback'),
                            onPressed: () => _openNormal(controller),
                            icon: const Icon(Icons.open_in_full,
                                color: Colors.white)),
                        IconButton(
                            tooltip: context.tr('Mute'),
                            onPressed: controller.toggleMute,
                            icon: Icon(
                                controller.isMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white)),
                        TextButton(
                            onPressed: controller.cyclePlaybackSpeed,
                            child: Text('${controller.playbackSpeed}×',
                                style: const TextStyle(color: Colors.white))),
                        ReelsSortMenu(
                            onSortSelected: controller.changeSortOrder,
                            theme: Theme.of(context),
                            onRefresh: () =>
                                controller.loadReels(forceRefresh: true)),
                      ]))),
              if (controller.isLoading && controller.reelsVideos.isNotEmpty)
                const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator()),
            ])));
  }
}
