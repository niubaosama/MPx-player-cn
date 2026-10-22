import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';

class CustomFolderBackHint extends StatelessWidget {
  const CustomFolderBackHint({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.tr('Tap back to return'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
