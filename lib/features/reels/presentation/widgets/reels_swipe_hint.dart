import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';

class ReelsSwipeHint extends StatelessWidget {
  final bool showExitHint;

  const ReelsSwipeHint({
    super.key,
    required this.showExitHint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: showExitHint ? 1 : 0.72,
      duration: const Duration(milliseconds: 260),
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swipe_right_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('Swipe right to leave Reels'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
