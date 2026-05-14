import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/commands/favorite_command_provider.dart';

class WordFavoriteButton extends ConsumerStatefulWidget {
  const WordFavoriteButton({
    super.key,
    required this.wordId,
    this.bookId,
    this.initialIsFavorited = false,
  });

  final String wordId;
  final String? bookId;
  final bool initialIsFavorited;

  @override
  ConsumerState<WordFavoriteButton> createState() => _WordFavoriteButtonState();
}

class _WordFavoriteButtonState extends ConsumerState<WordFavoriteButton> {
  bool _isSubmitting = false;
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
  }

  @override
  void didUpdateWidget(covariant WordFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId ||
        oldWidget.initialIsFavorited != widget.initialIsFavorited) {
      _isFavorited = widget.initialIsFavorited;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _isFavorited
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);

    return Tooltip(
      message: _isFavorited ? l10n.actionUnfavorite : l10n.actionFavorite,
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
                    final favorited = await ref
                        .read(favoriteCommandProvider)
                        .toggleWordFavorite(
                          wordId: widget.wordId,
                          bookId: widget.bookId,
                        );
                    if (mounted) {
                      setState(() => _isFavorited = favorited);
                    }
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
            _isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
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
