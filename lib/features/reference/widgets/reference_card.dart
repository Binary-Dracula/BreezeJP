import 'package:flutter/material.dart';
import '../reference_models.dart';

class ReferenceCard extends StatelessWidget {
  final ReferenceItem item;

  const ReferenceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 高亮颜色，使用 error container 上的主色或 primary
    final highlightColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  item.character,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.isIrregular
                        ? highlightColor
                        : theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.kana,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.isIrregular ? highlightColor : textColor,
                    ),
                  ),
                  if (item.romaji != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.romaji!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.translation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.translation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.isIrregular)
              Icon(Icons.star_rounded, color: highlightColor, size: 20),
          ],
        ),
      ),
    );
  }
}
