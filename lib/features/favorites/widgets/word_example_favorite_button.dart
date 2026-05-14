import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/commands/favorite_command_provider.dart';

class WordExampleFavoriteButton extends ConsumerStatefulWidget {
  const WordExampleFavoriteButton({
    super.key,
    required this.exampleId,
    required this.wordId,
    this.initialIsFavorited = false,
  });

  final String exampleId;
  final String wordId;
  final bool initialIsFavorited;

  @override
  ConsumerState<WordExampleFavoriteButton> createState() =>
      _WordExampleFavoriteButtonState();
}

class _WordExampleFavoriteButtonState
    extends ConsumerState<WordExampleFavoriteButton> {
  bool _isSubmitting = false;
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
  }

  @override
  void didUpdateWidget(covariant WordExampleFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exampleId != widget.exampleId ||
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
      message: _isFavorited
          ? l10n.actionUnfavoriteSentence
          : l10n.actionFavoriteSentence,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    final favorited = await ref
                        .read(favoriteCommandProvider)
                        .toggleWordExampleFavorite(
                          exampleId: widget.exampleId,
                          wordId: widget.wordId,
                        );
                    if (mounted) {
                      setState(() => _isFavorited = favorited);
                    }
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exampleFavoriteToggleFailed)),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          icon: Icon(
            _isFavorited
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: color,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ),
    );
  }
}
