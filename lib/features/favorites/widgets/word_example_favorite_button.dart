import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/commands/favorite_command_provider.dart';
import '../providers/favorite_state_provider.dart';

class WordExampleFavoriteButton extends ConsumerStatefulWidget {
  const WordExampleFavoriteButton({
    super.key,
    required this.exampleId,
    required this.wordId,
  });

  final String exampleId;
  final String wordId;

  @override
  ConsumerState<WordExampleFavoriteButton> createState() =>
      _WordExampleFavoriteButtonState();
}

class _WordExampleFavoriteButtonState
    extends ConsumerState<WordExampleFavoriteButton> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favoriteState = ref.watch(
      wordExampleFavoriteStateProvider(widget.exampleId),
    );
    final isFavorited = favoriteState.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    final color = isFavorited
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);

    return Tooltip(
      message: isFavorited
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
                    await ref
                        .read(favoriteCommandProvider)
                        .toggleWordExampleFavorite(
                          exampleId: widget.exampleId,
                          wordId: widget.wordId,
                        );
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
            isFavorited
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
