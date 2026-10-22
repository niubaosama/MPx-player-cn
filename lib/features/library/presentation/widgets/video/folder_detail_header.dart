import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../services/video_metadata_service.dart';
import '../../../domain/entities/video_folder.dart';

class FolderDetailHeader extends StatefulWidget {
  final VideoFolder folder;
  final VoidCallback onBackPressed;

  const FolderDetailHeader({
    super.key,
    required this.folder,
    required this.onBackPressed,
  });

  @override
  State<FolderDetailHeader> createState() => _FolderDetailHeaderState();
}

class _FolderDetailHeaderState extends State<FolderDetailHeader> {
  int _durationMs = 0;
  bool _isLoadingDuration = true;

  @override
  void initState() {
    super.initState();
    _loadDuration();
  }

  Future<void> _loadDuration() async {
    // Check if we need to extract durations
    final videosWithZeroDuration =
        widget.folder.videos.where((v) => v.duration == 0).toList();

    if (videosWithZeroDuration.isEmpty) {
      // All videos have duration
      setState(() {
        _durationMs = widget.folder.videos.fold(0, (sum, video) => sum + video.duration);
        _isLoadingDuration = false;
      });
      return;
    }

    // Extract durations for videos that don't have them
    int totalDuration = widget.folder.videos
        .where((v) => v.duration > 0)
        .fold(0, (sum, v) => sum + v.duration);

    // Extract missing durations in parallel
    final futures = videosWithZeroDuration.map((video) async {
      try {
        final metadata =
            await VideoMetadataService().extractMetadata(video.path);
        return metadata?.duration?.inMilliseconds ?? 0;
      } catch (_) {
        return 0;
      }
    });
    final durations = await Future.wait(futures);
    for (final d in durations) {
      totalDuration += d;
    }

    if (mounted) {
      setState(() {
        _durationMs = totalDuration;
        _isLoadingDuration = false;
      });
    }
  }

  String _formatDuration(int durationMs) {
    if (durationMs == 0) return context.tr('{value0}s', {'value0': 0});

    final hours = durationMs ~/ 3600000;
    final minutes = (durationMs % 3600000) ~/ 60000;
    final seconds = (durationMs % 60000) ~/ 1000;

    if (hours > 0) {
      return context.tr('{value0}h {value1}m', {'value0': hours, 'value1': minutes.toString().padLeft(2, '0')});
    } else if (minutes > 0) {
      return context.tr('{value0}m {value1}s', {'value0': minutes, 'value1': seconds.toString().padLeft(2, '0')});
    } else {
      return context.tr('{value0}s', {'value0': seconds});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBackPressed,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folder.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      context.tr('{value0} videos • {value1}', {'value0': widget.folder.videoCount, 'value1': widget.folder.formattedSize}),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_isLoadingDuration)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      )
                    else
                      Text(
                        ' • ${_formatDuration(_durationMs)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
