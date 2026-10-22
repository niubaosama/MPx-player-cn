import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../controller/player_controller.dart';

class FontSizeControl extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback onChanged;

  const FontSizeControl({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(context.tr('Font Size'),
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('A',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: controller.subtitleFontSize,
                  min: 12,
                  max: 48,
                  divisions: 12,
                  onChanged: (value) {
                    controller.setSubtitleFontSize(value);
                    onChanged();
                  },
                ),
              ),
              const Text('A',
                  style: TextStyle(color: Colors.grey, fontSize: 20)),
            ],
          ),
        ),
        Center(
          child: Text(
            '${controller.subtitleFontSize.toInt()}pt',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
