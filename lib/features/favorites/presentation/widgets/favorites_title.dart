import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../../../core/theme/app_theme_tokens.dart';

class FavoritesTitle extends StatelessWidget {
  final int videoCount;

  const FavoritesTitle({super.key, required this.videoCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Favorites'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: theme.strongText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          videoCount == 0
              ? context.tr('Your saved videos live here')
              : context.tr('{value0} saved {value1} ready to play', {'value0': videoCount, 'value1': videoCount == 1 ? 'video' : 'videos'}),
          style: TextStyle(
            fontSize: 14,
            color: theme.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
