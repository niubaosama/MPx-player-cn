import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../../../core/theme/app_theme_tokens.dart';

class HistoryHeader extends StatelessWidget {
  final int videoCount;
  final ValueChanged<String>? onSearchChanged;
  final String searchQuery;
  final VoidCallback? onClearSearch;
  final VoidCallback? onClearHistory;

  const HistoryHeader({
    super.key,
    required this.videoCount,
    this.onSearchChanged,
    this.searchQuery = '',
    this.onClearSearch,
    this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('History'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: theme.strongText,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (videoCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr('{value0} recently watched', {'value0': videoCount}),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (videoCount > 0 && onClearHistory != null)
                GestureDetector(
                  onTap: onClearHistory,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Clear'),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.softBorder),
      ),
      child: TextField(
        onChanged: onSearchChanged,
        style: TextStyle(fontSize: 14, color: theme.strongText),
        decoration: InputDecoration(
          hintText: context.tr('Search history...'),
          hintStyle: TextStyle(color: theme.faintText, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: theme.faintText, size: 20),
          suffixIcon: searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: onClearSearch,
                  child: Icon(Icons.clear, color: theme.faintText, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
