import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/l10n/app_localizations.dart';
import '../../controllers/reels_controller.dart';

class ReelSourcesSheet extends StatefulWidget {
  final ReelsController controller;

  const ReelSourcesSheet({super.key, required this.controller});

  @override
  State<ReelSourcesSheet> createState() => _ReelSourcesSheetState();
}

class _ReelSourcesSheetState extends State<ReelSourcesSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFolder() => _run(() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) await widget.controller.importFolderToReels(path);
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final sources = widget.controller.sources;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(context.tr('Reels sources'),
                      style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.pop(context),
                      tooltip: context.tr('Close'), icon: const Icon(Icons.close)),
                ]),
                Text(context.tr('Videos stay in their original folders. No files are copied.')),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: Column(
                  children: [
                    if (sources.isEmpty) Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.tr('No sources added yet')),
                    ),
                    for (final source in sources) Card(child: Column(children: [
                      ListTile(
                        leading: Icon(source.isFolder ? Icons.folder_outlined : Icons.video_file_outlined),
                        title: Text(p.basename(source.path)),
                        subtitle: Text(source.path),
                        trailing: IconButton(
                          tooltip: context.tr('Remove source'),
                          icon: const Icon(Icons.link_off),
                          onPressed: _busy ? null : () => _run(() =>
                              widget.controller.removeSource(source.path)),
                        ),
                      ),
                      if (source.isFolder) SwitchListTile(
                        title: Text(context.tr('Include subfolders')),
                        value: source.includeSubfolders,
                        onChanged: _busy ? null : (enabled) => _run(() =>
                            widget.controller.setIncludeSubfolders(source.path, enabled)),
                      ),
                    ])),
                  ],
                ))),
                if (_error != null) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.tr('Unable to update sources: {value0}', {'value0': _error}),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _addFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(context.tr('Add folder')),
                ),
                const SizedBox(height: 8),
                Text(context.tr('Removing a source keeps all original videos.')),
              ],
            );
          },
        ),
      ),
    );
  }
}
