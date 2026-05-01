import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/commands/favorite_command_provider.dart';
import '../providers/favorite_state_provider.dart';

class WordFavoriteButton extends ConsumerStatefulWidget {
  const WordFavoriteButton({super.key, required this.wordId, this.bookId});

  final String wordId;
  final String? bookId;

  @override
  ConsumerState<WordFavoriteButton> createState() => _WordFavoriteButtonState();
}

class _WordFavoriteButtonState extends ConsumerState<WordFavoriteButton> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favoriteState = ref.watch(wordFavoriteStateProvider(widget.wordId));
    final isFavorited = favoriteState.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    final color = isFavorited
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);

    return Tooltip(
      message: isFavorited ? l10n.actionUnfavorite : l10n.actionFavorite,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: IconButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await ref
                        .read(favoriteCommandProvider)
                        .toggleWordFavorite(
                          wordId: widget.wordId,
                          bookId: widget.bookId,
                        );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.wordFavoriteToggleFailed)),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          icon: Icon(
            isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
            color: color,
            size: 22,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ),
    );
  }
}
