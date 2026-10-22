import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/features/reels/presentation/widgets/reel_player_item.dart';
import 'package:mpx/features/reels/presentation/widgets/empty_reels_view.dart';
import 'package:mpx/features/reels/presentation/widgets/reels_sort_menu.dart';
import 'package:mpx/features/reels/presentation/widgets/reels_swipe_hint.dart';
import 'package:mpx/features/reels/presentation/widgets/custom_folder_back_button.dart';
import 'package:mpx/features/reels/presentation/widgets/custom_folder_back_hint.dart';
import '../widgets/reel_sources_sheet.dart';
import 'package:mpx/core/theme/app_theme_tokens.dart';

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  final String? folderPath;

  const ReelsScreen({
    super.key,
    this.isActive = true,
    this.folderPath,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isAppActive = true;
  bool _showExitHint = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showExitHint = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() {
        _isAppActive = state == AppLifecycleState.resumed;
      });
    }
  }

  @override
  void didUpdateWidget(ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _manageSources(ReelsController controller) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ReelSourcesSheet(controller: controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustomFolder = widget.folderPath != null;

    return isCustomFolder
        ? ChangeNotifierProvider(
            create: (_) => ReelsController(targetFolderPath: widget.folderPath),
            child: _buildContent(context, theme, isCustomFolder),
          )
        : _buildContent(context, theme, isCustomFolder);
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, bool isCustomFolder) {
    return Consumer<ReelsController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.reelsVideos.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.error != null) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(context.tr('Error: {value0}', {'value0': controller.error}),
                    style: TextStyle(color: theme.colorScheme.error)),
                if (!isCustomFolder) TextButton(onPressed: () => _manageSources(controller),
                    child: Text(context.tr('Manage sources'))),
                TextButton(onPressed: () => controller.loadReels(forceRefresh: true),
                    child: Text(context.tr('Retry'))),
              ]),
            ),
          );
        }

        if (controller.reelsVideos.isEmpty) {
          return EmptyReelsView(
            isCustomFolder: isCustomFolder,
            onImportFolder: isCustomFolder ? null : () => _manageSources(controller),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: RefreshIndicator(
            onRefresh: () => controller.loadReels(forceRefresh: true),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemCount: controller.reelsVideos.length,
                  itemBuilder: (context, index) {
                    final video = controller.reelsVideos[index];
                    return ReelPlayerItem(
                      video: video,
                      isCurrentlyVisible: widget.isActive &&
                          _currentPage == index &&
                          _isAppActive,
                      playbackSpeed: controller.playbackSpeed,
                      isPaused: controller.isPaused,
                      onTogglePause: controller.togglePause,
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: SafeArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isCustomFolder) IconButton(
                          tooltip: context.tr('Manage sources'),
                          icon: const Icon(Icons.folder_open, color: Colors.white),
                          onPressed: () => _manageSources(controller),
                        ),
                        GestureDetector(
                          onTap: controller.cyclePlaybackSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  theme.elevatedSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${controller.playbackSpeed}x',
                              style: TextStyle(
                                color: theme.strongText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ReelsSortMenu(
                          onSortSelected: controller.changeSortOrder,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isCustomFolder)
                  Positioned(
                    top: 40,
                    left: 20,
                    child: SafeArea(
                      child: ReelsSwipeHint(showExitHint: _showExitHint),
                    ),
                  ),
                if (isCustomFolder) ...[
                  Positioned(
                    top: 40,
                    left: 20,
                    child: SafeArea(
                      child: CustomFolderBackButton(
                        onBack: () => Navigator.pop(context),
                        theme: theme,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 96,
                    left: 20,
                    child: SafeArea(
                      child: CustomFolderBackHint(),
                    ),
                  ),
                ],
                if (controller.isLoading)
                  const Positioned(
                    top: 50,
                    right: 20,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
