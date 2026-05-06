import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/network_error_view.dart';
import '../../../core/widgets/review_spelling_options.dart';
import '../../../core/widgets/review_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/word_detail.dart';
import '../../../services/audio_service_provider.dart';
import '../../word_detail/widgets/word_detail_content.dart';
import '../controller/word_review_controller.dart';
import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

class WordReviewPage extends ConsumerStatefulWidget {
  const WordReviewPage({super.key});

  @override
  ConsumerState<WordReviewPage> createState() => _WordReviewPageState();
}

class _WordReviewPageState extends ConsumerState<WordReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordReviewControllerProvider.notifier).loadReview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(wordReviewControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          l10n.wordReviewTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () async {
            await _handlePop();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _buildBody(context, state, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WordReviewState state,
    AppLocalizations l10n,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isNetworkError) {
      return NetworkErrorView(
        onRetry: () =>
            ref.read(wordReviewControllerProvider.notifier).loadReview(),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(wordReviewControllerProvider.notifier).loadReview(),
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return ReviewEmptyState(title: l10n.wordReviewEmpty);
    }

    if (state.isAllFinished) {
      return ReviewFinishedState(
        onBack: () async {
          await _handlePop();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    }

    final item = state.currentItem;
    if (item == null) return const SizedBox.shrink();

    return Column(
      children: [
        ReviewProgressBar(
          progress: state.progress,
          currentIndex: state.currentIndex,
          totalItems: state.items.length,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildQuestionCard(item, state.currentPhase, l10n),
                const SizedBox(height: 60),
                if (state.currentPhase == ReviewCardPhase.testing)
                  if (item.questionType ==
                      WordReviewQuestionType.meaningToSpelling)
                    ReviewSpellingOptions(
                      options: state.currentOptions,
                      correctSpelling: item.reading ?? '',
                      hasMistake: state.hasMistakeOnCurrent,
                      onSelect: (option) => ref
                          .read(wordReviewControllerProvider.notifier)
                          .submitObjectiveAnswer(option),
                    )
                  else
                    ReviewObjectiveListOptions(
                      options: state.currentOptions,
                      correctOption: _getCorrectOption(item),
                      onSelect: (option) => ref
                          .read(wordReviewControllerProvider.notifier)
                          .submitObjectiveAnswer(option),
                    )
                else
                  _buildContinueButton(l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () =>
            ref.read(wordReviewControllerProvider.notifier).continueToNext(),
        child: Text(
          l10n.wordReviewContinue,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    WordReviewItem item,
    ReviewCardPhase phase,
    AppLocalizations l10n,
  ) {
    String subTitle = _titleForType(item.questionType, l10n);
    Widget titleWidget;

    switch (item.questionType) {
      case WordReviewQuestionType.meaningToSpelling:
        titleWidget = Text(
          item.meaning ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        );
        break;
      case WordReviewQuestionType.audioToMeaning:
        titleWidget = IconButton(
          iconSize: 64,
          color: const Color(0xFF6C63FF),
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            final src = item.audioSource ?? '';
            if (src.isNotEmpty) {
              ref.read(audioServiceProvider).playAudio(src);
            }
          },
        );
        break;
      case WordReviewQuestionType.kanjiToReading:
        titleWidget = Text(
          item.wordDetail.word.word,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        );
        break;
      case WordReviewQuestionType.wordToMeaning:
        titleWidget = Text(
          item.wordDetail.word.word,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        );
        break;
      case WordReviewQuestionType.clozeTest:
        titleWidget = Text(
          item.clozeSentence ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3142),
            height: 1.7,
          ),
        );
        break;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                subTitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
              const SizedBox(height: 24),
              titleWidget,
              if (phase == ReviewCardPhase.grading) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                Text(
                  item.wordDetail.word.word,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.reading != null && item.reading!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.reading!,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  item.meaning ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.grey),
            onPressed: () => _showWordDetailSheet(context, item.wordDetail),
          ),
        ),
      ],
    );
  }

  void _showWordDetailSheet(BuildContext context, WordDetail wordDetail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          snap: true,
          snapSizes: const [0.6, 0.9],
          builder: (context, scrollController) {
            return SafeArea(
              top: false,
              child: WordDetailContent(
                wordDetail: wordDetail,
                scrollController: scrollController,
                prefixChildren: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getCorrectOption(WordReviewItem item) {
    switch (item.questionType) {
      case WordReviewQuestionType.wordToMeaning:
      case WordReviewQuestionType.audioToMeaning:
        return item.meaning ?? 'Unknown';
      case WordReviewQuestionType.kanjiToReading:
      case WordReviewQuestionType.meaningToSpelling:
        return item.reading ?? '';
      case WordReviewQuestionType.clozeTest:
        return item.wordDetail.word.word;
    }
  }

  Future<bool> _handlePop() async {
    await ref.read(wordReviewControllerProvider.notifier).endSession();
    return true;
  }
}

String _titleForType(WordReviewQuestionType type, AppLocalizations l10n) {
  return switch (type) {
    WordReviewQuestionType.wordToMeaning => l10n.wordReviewTitleWordMeaning,
    WordReviewQuestionType.meaningToSpelling => l10n.wordReviewTitleMeaningWord,
    WordReviewQuestionType.audioToMeaning => l10n.wordReviewTitleAudioWord,
    WordReviewQuestionType.kanjiToReading => l10n.wordReviewTitleReadingWord,
    WordReviewQuestionType.clozeTest => l10n.wordReviewTitleClozeTest,
  };
}
