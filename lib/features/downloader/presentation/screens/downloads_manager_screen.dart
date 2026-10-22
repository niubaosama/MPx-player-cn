import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../controller/downloader_controller.dart';
import '../../domain/entities/download_item.dart';
import '../../services/downloader_settings_service.dart';
import '../helpers/download_player_launcher.dart';
import '../widgets/download_progress_tile.dart';
import '../widgets/empty_downloads_placeholder.dart';
import 'downloader_tab_screen.dart';

class DownloadsManagerScreen extends StatefulWidget {
  const DownloadsManagerScreen({super.key, this.initialSharedUrl});

  final String? initialSharedUrl;

  @override
  State<DownloadsManagerScreen> createState() => _DownloadsManagerScreenState();
}

class _DownloadsManagerScreenState extends State<DownloadsManagerScreen> {
  bool _handledSharedUrl = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialSharedUrl();
    });
  }

  Future<void> _handleInitialSharedUrl() async {
    final sharedUrl = widget.initialSharedUrl;
    if (_handledSharedUrl ||
        sharedUrl == null ||
        sharedUrl.isEmpty ||
        !mounted) {
      return;
    }

    _handledSharedUrl = true;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => DownloaderTabScreen(
          initialUrl: sharedUrl,
          autoSubmit: true,
          launchedFromShare: DownloaderSettingsService.autoDownloadSharedLinks,
        ),
      ),
    );
    if (mounted) {
      await context.read<DownloaderController>().refreshDownloads();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DownloaderController>();
    final state = controller.state;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Downloader')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('Active')),
              Tab(text: context.tr('Completed')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DownloadsList(
              items: state.activeDownloads,
              emptyTitle: context.tr('No active downloads'),
              emptySubtitle: context.tr('Start a new task to track progress here.'),
            ),
            _DownloadsList(
              items: state.completedDownloads,
              emptyTitle: context.tr('Nothing finished yet'),
              emptySubtitle: context.tr('Completed downloads will show up here.'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DownloaderTabScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(context.tr('Add')),
        ),
      ),
    );
  }
}

class _DownloadsList extends StatelessWidget {
  const _DownloadsList({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<DownloadItem> items;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DownloaderController>();

    if (items.isEmpty) {
      return EmptyDownloadsPlaceholder(
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshDownloads,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return DownloadProgressTile(
            item: item,
            onPause: () => controller.pauseDownload(item.id),
            onResume: () => controller.resumeDownload(item.id),
            onCancel: () => controller.cancelDownload(item.id),
            onDelete: () => controller.deleteDownload(item.id),
            onRetry: () => controller.retryDownload(item.id),
            onPlay: item.savePath == null
                ? null
                : () => openDownloadedVideo(context, item.savePath!),
          );
        },
      ),
    );
  }
}
