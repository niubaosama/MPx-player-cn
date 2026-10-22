import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/core/theme/app_theme_tokens.dart';

class EmptyReelsView extends StatelessWidget {
  final bool isCustomFolder;
  final VoidCallback? onImportFolder;

  const EmptyReelsView({
    super.key,
    required this.isCustomFolder,
    this.onImportFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.appBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_rounded,
              size: 80,
              color: theme.faintText,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('No Reels yet!'),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.strongText),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Add one or more folders, or add a video from its details. No files are copied.'),
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.mutedText),
            ),
            const SizedBox(height: 24),
            if (!isCustomFolder) _buildImportButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: onImportFolder,
      icon: const Icon(Icons.folder_open_rounded),
      label: Text(context.tr('Manage sources')),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
