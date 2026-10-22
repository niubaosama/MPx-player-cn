import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/features/reels/controllers/reels_controller.dart';
import 'package:mpx/core/theme/app_theme_tokens.dart';

class ReelsSortMenu extends StatelessWidget {
  final void Function(ReelsSortOrder) onSortSelected;
  final ThemeData theme;

  const ReelsSortMenu({
    super.key,
    required this.onSortSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: PopupMenuButton<ReelsSortOrder>(
        icon: Icon(Icons.sort_rounded, color: theme.strongText),
        onSelected: onSortSelected,
        itemBuilder: (context) => [
           PopupMenuItem(
            value: ReelsSortOrder.dateDesc,
            child: Text(context.tr('Newest First')),
          ),
           PopupMenuItem(
            value: ReelsSortOrder.dateAsc,
            child: Text(context.tr('Oldest First')),
          ),
           PopupMenuItem(
            value: ReelsSortOrder.nameAsc,
            child: Text(context.tr('By Name')),
          ),
           PopupMenuItem(
            value: ReelsSortOrder.shuffle,
            child: Text(context.tr('Shuffle')),
          ),
        ],
      ),
    );
  }
}
