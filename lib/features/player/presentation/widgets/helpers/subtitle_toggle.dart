import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../controller/player_controller.dart';

class SubtitleToggle extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback onChanged;

  const SubtitleToggle({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title:
          Text(context.tr('Enable Subtitles'), style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        context.tr('Subtitles will auto-detect'),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      value: controller.subtitlesEnabled,
      onChanged: (value) {
        controller.toggleSubtitles(value);
        onChanged();
      },
    );
  }
}
