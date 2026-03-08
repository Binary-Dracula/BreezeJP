import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/review_widgets.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../word_review/state/word_review_state.dart';
import '../controller/kana_review_controller.dart';
import '../state/kana_review_state.dart';
import '../state/review_kana_item.dart';

class KanaReviewPage extends ConsumerStatefulWidget {
  const KanaReviewPage({super.key});

  @override
  ConsumerState<KanaReviewPage> createState() => _KanaReviewPageState();
}

class _KanaReviewPageState extends ConsumerState<KanaReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kanaReviewControllerProvider.notifier).loadReview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kanaReviewControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          '五十音复习',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(KanaReviewState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmpty) {
      return const ReviewEmptyState(title: '暂无待复习假名');
    }

    if (state.isAllFinished) {
      return ReviewFinishedState(onBack: () => Navigator.of(context).pop());
    }

    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}'));
    }

    final item = state.currentItem;
    if (item == null) return const SizedBox.shrink();

    return Column(
      children: [
        // 进度条
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
                _buildQuestionCard(item, state.currentPhase),
                const SizedBox(height: 60),
                if (state.currentPhase == ReviewCardPhase.testing)
                  ReviewObjectiveOptions(
                    options: state.currentOptions,
                    onSelect: (option) => ref
                        .read(kanaReviewControllerProvider.notifier)
                        .submitObjectiveAnswer(option),
                  )
                else
                  ReviewSubjectiveRatings(
                    onRate: (rating) => ref
                        .read(kanaReviewControllerProvider.notifier)
                        .submitSubjectiveRating(rating),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(ReviewKanaItem item, ReviewCardPhase phase) {
    String title = '';
    String subTitle = '';

    switch (item.questionType) {
      case ReviewQuestionType.hiraganaToRomaji:
        title = item.kanaLetter.kanaChar;
        subTitle = '该平假名的罗马音是？';
        break;
      case ReviewQuestionType.romajiToHiragana:
        title = item.kanaLetter.romaji;
        subTitle = '该罗马音对应的平假名是？';
        break;
      case ReviewQuestionType.katakanaToRomaji:
        title = item.kanaLetter.kanaChar;
        subTitle = '该片假名的罗马音是？';
        break;
      case ReviewQuestionType.romajiToKatakana:
        title = item.kanaLetter.romaji;
        subTitle = '该罗马音对应的片假名是？';
        break;
      case ReviewQuestionType.hiraganaToKatakana:
        title = item.kanaLetter.kanaChar;
        subTitle = '该平假名对应的片假名是？';
        break;
      case ReviewQuestionType.katakanaToHiragana:
        title = item.kanaLetter.kanaChar;
        subTitle = '该片假名对应的平假名是？';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          if (phase == ReviewCardPhase.grading) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              item.kanaLetter.romaji,
              style: const TextStyle(
                fontSize: 24,
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${item.kanaLetter.kanaChar} (${item.kanaLetter.scriptKind == KanaScriptKind.hiragana ? "平假名" : "片假名"})',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
