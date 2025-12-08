import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/repositories/active_user_provider.dart';
import '../../../../data/repositories/kana_repository.dart';
import '../../../../data/repositories/kana_repository_provider.dart';
import '../state/kana_review_state.dart';

final kanaReviewControllerProvider =
    NotifierProvider<KanaReviewController, KanaReviewState>(
      KanaReviewController.new,
    );

class KanaReviewController extends Notifier<KanaReviewState> {
  KanaRepository get _repo => ref.read(kanaRepositoryProvider);

  @override
  KanaReviewState build() => const KanaReviewState();

  Future<void> loadReviewList() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await ref.read(activeUserProvider.future);
      final learningStates = await _repo.getDueReviewKana(user.id);
      final items = await _composeReviewItems(user.id, learningStates);

      state = state.copyWith(
        isLoading: false,
        reviewList: items,
        currentIndex: 0,
        isFinished: items.isEmpty,
        phase: KanaReviewPhase.question,
      );
      logger.info('假名复习队列加载成功: ${items.length} 个待复习');
    } catch (e, stackTrace) {
      logger.error('加载假名复习队列失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool get isLastItem =>
      state.currentIndex >= state.reviewList.length - 1 &&
      state.reviewList.isNotEmpty;

  bool get isFirstItem => state.currentIndex <= 0;

  Future<void> next() async {
    if (isLastItem) {
      state = state.copyWith(isFinished: true);
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      phase: KanaReviewPhase.question,
    );
  }

  Future<void> prev() async {
    if (isFirstItem) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      phase: KanaReviewPhase.question,
    );
  }

  /// 切换到显示答案阶段
  void showAnswer() {
    state = state.copyWith(phase: KanaReviewPhase.answer);
  }

  Future<List<ReviewKanaItem>> _composeReviewItems(
    int userId,
    List<KanaLearningState> learningStates,
  ) async {
    final List<ReviewKanaItem> items = [];

    for (final learningState in learningStates) {
      final KanaLetter? letter = await _repo.getKanaLetterById(
        learningState.kanaId,
      );
      if (letter == null) {
        logger.warning('假名不存在，跳过复习项: kanaId=${learningState.kanaId}');
        continue;
      }
      final audio = await _repo.getKanaAudio(learningState.kanaId);
      final lastType = await _repo.getLastKanaReviewQuestionType(
        userId,
        learningState.kanaId,
      );
      final questionType = _chooseQuestionType(learningState, lastType);
      items.add(
        ReviewKanaItem(
          kanaLetter: letter,
          learningState: learningState,
          audioFilename: audio?.audioFilename,
          questionType: questionType,
        ),
      );
    }

    return items;
  }

  ReviewQuestionType _chooseQuestionType(
    KanaLearningState learningState,
    String? lastType,
  ) {
    final level = _judgeLevel(learningState);
    final priorities = switch (level) {
      _SkillLevel.weak => [
        ReviewQuestionType.audio,
        ReviewQuestionType.switchMode,
        ReviewQuestionType.recall,
      ],
      _SkillLevel.newbie => [
        ReviewQuestionType.switchMode,
        ReviewQuestionType.audio,
      ],
      _SkillLevel.strong => [
        ReviewQuestionType.recall,
        ReviewQuestionType.switchMode,
        ReviewQuestionType.audio,
      ],
    };

    final primary = priorities.first;
    final secondary = priorities.length > 1 ? priorities[1] : primary;

    if (lastType != null) {
      final normalizedLast = _mapStringToQuestionType(lastType);
      if (normalizedLast != null && normalizedLast == primary) {
        return secondary;
      }
    }
    return primary;
  }

  _SkillLevel _judgeLevel(KanaLearningState state) {
    if (state.failCount >= 3) return _SkillLevel.weak;
    if (state.streak <= 1) return _SkillLevel.newbie;
    return _SkillLevel.strong;
  }

  ReviewQuestionType? _mapStringToQuestionType(String value) {
    switch (value) {
      case 'recall':
        return ReviewQuestionType.recall;
      case 'audio':
        return ReviewQuestionType.audio;
      case 'switchMode':
        return ReviewQuestionType.switchMode;
      default:
        return null;
    }
  }
}

enum _SkillLevel { weak, newbie, strong }
