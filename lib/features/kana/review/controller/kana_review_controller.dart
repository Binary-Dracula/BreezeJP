import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/commands/active_user_command.dart';
import '../../../../data/commands/active_user_command_provider.dart';
import '../../../../data/commands/kana_command.dart';
import '../../../../data/commands/kana_command_provider.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/models/study_log.dart';
import '../../../../data/models/user.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/queries/kana_query.dart';
import '../../../../data/queries/kana_query_provider.dart';
import '../../../word_review/state/word_review_state.dart';
import '../state/kana_review_state.dart';
import '../state/review_kana_item.dart';

final kanaReviewControllerProvider =
    NotifierProvider<KanaReviewController, KanaReviewState>(
      KanaReviewController.new,
    );

class KanaReviewController extends Notifier<KanaReviewState> {
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  KanaCommand get _kanaCommand => ref.read(kanaCommandProvider);

  @override
  KanaReviewState build() => const KanaReviewState();

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  void _setSessionBootstrapState({
    required bool isLoading,
    required bool isEmpty,
  }) {
    state = state.copyWith(
      isLoading: isLoading,
      isEmpty: isEmpty,
      items: const [],
      currentIndex: 0,
      currentPhase: ReviewCardPhase.testing,
      hasMistakeOnCurrent: false,
      currentOptions: const [],
      isAllFinished: false,
      error: null,
    );
  }

  Future<void> loadReview() async {
    try {
      _setSessionBootstrapState(isLoading: true, isEmpty: false);

      final user = await _getActiveUser();
      final learningStates = await _kanaQuery.getDueReviewKana(user.id);

      final items = await _composeReviewItems(user.id, learningStates);
      if (items.isEmpty) {
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        return;
      }

      // 打乱顺序
      items.shuffle();

      state = state.copyWith(
        isLoading: false,
        isEmpty: false,
        items: items,
        currentIndex: 0,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
        isAllFinished: false,
        error: null,
      );

      await _prepareCurrentCardOptions();
    } catch (e, stackTrace) {
      logger.error('Start kana review failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _prepareCurrentCardOptions() async {
    final item = state.currentItem;
    if (item == null) return;

    // 全量假名获取干扰项
    final allKanas = await _kanaQuery.getAllKanaLetters();
    final otherKanas = allKanas
        .where((k) => k.id != item.kanaLetter.id)
        .toList();
    otherKanas.shuffle();

    final options = <String>[];
    String correctOption = '';

    switch (item.questionType) {
      case ReviewQuestionType.hiraganaToRomaji:
      case ReviewQuestionType.katakanaToRomaji:
        correctOption = item.kanaLetter.romaji;
        options.add(correctOption);
        for (final k in otherKanas) {
          if (options.length >= 4) break;
          if (!options.contains(k.romaji)) options.add(k.romaji);
        }
        break;
      case ReviewQuestionType.romajiToHiragana:
      case ReviewQuestionType.katakanaToHiragana:
        correctOption =
            (item.questionType == ReviewQuestionType.romajiToHiragana)
            ? item.kanaLetter.kanaChar
            : (item.counterpartLetter?.kanaChar ?? item.kanaLetter.kanaChar);
        options.add(correctOption);
        for (final k in otherKanas) {
          if (options.length >= 4) break;
          if (k.scriptKind == KanaScriptKind.hiragana) {
            if (!options.contains(k.kanaChar)) options.add(k.kanaChar);
          }
        }
        break;
      case ReviewQuestionType.romajiToKatakana:
      case ReviewQuestionType.hiraganaToKatakana:
        correctOption =
            (item.questionType == ReviewQuestionType.romajiToKatakana)
            ? item.kanaLetter.kanaChar
            : (item.counterpartLetter?.kanaChar ?? item.kanaLetter.kanaChar);
        options.add(correctOption);
        for (final k in otherKanas) {
          if (options.length >= 4) break;
          if (k.scriptKind == KanaScriptKind.katakana) {
            if (!options.contains(k.kanaChar)) options.add(k.kanaChar);
          }
        }
        break;
    }

    // 补足选项逻辑
    if (options.length < 4) {
      for (final k in otherKanas) {
        if (options.length >= 4) break;
        if (!options.contains(k.kanaChar)) options.add(k.kanaChar);
      }
    }

    options.shuffle();
    state = state.copyWith(currentOptions: options);
  }

  Future<void> submitObjectiveAnswer(String selectedOption) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.testing) return;

    String correctOption = '';
    switch (item.questionType) {
      case ReviewQuestionType.hiraganaToRomaji:
      case ReviewQuestionType.katakanaToRomaji:
        correctOption = item.kanaLetter.romaji;
        break;
      case ReviewQuestionType.romajiToHiragana:
      case ReviewQuestionType.romajiToKatakana:
        correctOption = item.kanaLetter.kanaChar;
        break;
      case ReviewQuestionType.hiraganaToKatakana:
      case ReviewQuestionType.katakanaToHiragana:
        correctOption =
            item.counterpartLetter?.kanaChar ?? item.kanaLetter.kanaChar;
        break;
    }

    final isCorrect = selectedOption == correctOption;

    if (isCorrect) {
      state = state.copyWith(currentPhase: ReviewCardPhase.grading);
    } else {
      if (!state.hasMistakeOnCurrent) {
        state = state.copyWith(hasMistakeOnCurrent: true);
        try {
          await _kanaCommand.onKanaReviewed(
            userId: item.learningState.userId,
            kanaId: item.kanaLetter.id,
            rating: ReviewRating.again,
          );
        } catch (e) {
          logger.error('Failed to log kana again rating', e);
        }
      }
    }
  }

  Future<void> submitSubjectiveRating(ReviewRating selectedRating) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.grading) return;

    try {
      if (!state.hasMistakeOnCurrent) {
        await _kanaCommand.onKanaReviewed(
          userId: item.learningState.userId,
          kanaId: item.kanaLetter.id,
          rating: selectedRating,
        );
      }
    } catch (e) {
      logger.error('Failed to log kana rating', e);
    }

    await _goToNextCard();
  }

  Future<void> _goToNextCard() async {
    final items = List<ReviewKanaItem>.from(state.items);
    if (state.hasMistakeOnCurrent) {
      final currentItem = items[state.currentIndex];
      items.add(currentItem);
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= items.length) {
      state = state.copyWith(
        isAllFinished: true,
        items: items,
        currentIndex: nextIndex,
      );
    } else {
      state = state.copyWith(
        items: items,
        currentIndex: nextIndex,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
      );
      await _prepareCurrentCardOptions();
    }
  }

  Future<List<ReviewKanaItem>> _composeReviewItems(
    int userId,
    List<KanaLearningState> learningStates,
  ) async {
    final List<ReviewKanaItem> items = [];
    for (final s in learningStates) {
      final letter = await _kanaQuery.getKanaLetterById(s.kanaId);
      if (letter == null) continue;

      final audio = await _kanaQuery.getKanaAudioByKanaId(s.kanaId);
      final counterpart = await _kanaQuery.getKanaCounterpart(letter);

      // 根据 kanaId 和 scriptKind 分配初始题型
      ReviewQuestionType type;
      final seed = letter.id + s.userId;
      if (letter.scriptKind == KanaScriptKind.hiragana) {
        final r = seed % 3;
        if (r == 0) {
          type = ReviewQuestionType.hiraganaToRomaji;
        } else if (r == 1) {
          type = ReviewQuestionType.romajiToHiragana;
        } else {
          type = ReviewQuestionType.hiraganaToKatakana;
        }
      } else {
        final r = seed % 3;
        if (r == 0) {
          type = ReviewQuestionType.katakanaToRomaji;
        } else if (r == 1) {
          type = ReviewQuestionType.romajiToKatakana;
        } else {
          type = ReviewQuestionType.katakanaToHiragana;
        }
      }

      items.add(
        ReviewKanaItem(
          kanaLetter: letter,
          learningState: s,
          audioFilename: audio?.audioFilename,
          questionType: type,
          counterpartLetter: counterpart,
        ),
      );
    }
    return items;
  }
}
