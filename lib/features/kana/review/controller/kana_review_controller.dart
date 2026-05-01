import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/commands/active_user_command.dart';
import '../../../../data/commands/active_user_command_provider.dart';
import '../../../../data/commands/kana_command.dart';
import '../../../../data/commands/kana_command_provider.dart';
import '../../../../core/algorithm/srs_types.dart';
import '../../../../data/models/kana_letter.dart';
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
      sessionId: null,
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

  Future<void> loadReview({int limit = 20}) async {
    try {
      _setSessionBootstrapState(isLoading: true, isEmpty: false);

      final user = await _getActiveUser();
      final dueStates = await _kanaQuery.getDueReviewKana(user.id);
      if (dueStates.isEmpty) {
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        logger.info('No due kana for review.');
        return;
      }

      final allLetters = await _kanaQuery.getAllKanaLetters();
      allLetters.sort(
        (left, right) => (left.displayOrder ?? 1 << 30).compareTo(
          right.displayOrder ?? 1 << 30,
        ),
      );
      final letterById = <int, KanaLetter>{
        for (final letter in allLetters) letter.id: letter,
      };

      final items = <ReviewKanaItem>[];
      for (final learningState in dueStates.take(limit)) {
        final letter = letterById[learningState.kanaId];
        if (letter == null) {
          continue;
        }

        final counterpart = _resolveKanaCounterpart(letter, allLetters);
        final questionType = _chooseKanaReviewType(letter, user.id);
        items.add(
          ReviewKanaItem(
            kanaLetter: letter,
            learningState: learningState,
            audioFilename: null,
            questionType: questionType,
            options: _buildKanaOptions(
              questionType: questionType,
              letter: letter,
              counterpart: counterpart,
              allLetters: allLetters,
              userId: user.id,
            ),
            counterpartLetter: counterpart,
          ),
        );
      }

      if (items.isEmpty) {
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        return;
      }

      state = state.copyWith(
        sessionId: null,
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
    state = state.copyWith(currentOptions: item.options);
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
        currentOptions: const [],
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

  Future<void> endSession() async {}

  ReviewQuestionType _chooseKanaReviewType(KanaLetter letter, int userId) {
    final seed = _simpleHash('$userId:${letter.id}').abs() % 3;
    if (letter.scriptKind == KanaScriptKind.hiragana) {
      return seed == 0
          ? ReviewQuestionType.hiraganaToRomaji
          : seed == 1
          ? ReviewQuestionType.romajiToHiragana
          : ReviewQuestionType.hiraganaToKatakana;
    }
    return seed == 0
        ? ReviewQuestionType.katakanaToRomaji
        : seed == 1
        ? ReviewQuestionType.romajiToKatakana
        : ReviewQuestionType.katakanaToHiragana;
  }

  List<String> _buildKanaOptions({
    required ReviewQuestionType questionType,
    required KanaLetter letter,
    required KanaLetter? counterpart,
    required List<KanaLetter> allLetters,
    required int userId,
  }) {
    final otherLetters = allLetters
        .where((item) => item.id != letter.id)
        .toList();
    final options = <String>[];

    switch (questionType) {
      case ReviewQuestionType.hiraganaToRomaji:
      case ReviewQuestionType.katakanaToRomaji:
        options.add(letter.romaji);
        for (final item in otherLetters) {
          if (!options.contains(item.romaji)) {
            options.add(item.romaji);
          }
          if (options.length >= 4) {
            break;
          }
        }
        break;
      case ReviewQuestionType.romajiToHiragana:
      case ReviewQuestionType.katakanaToHiragana:
        options.add(
          questionType == ReviewQuestionType.romajiToHiragana
              ? letter.kanaChar
              : counterpart?.kanaChar ?? letter.kanaChar,
        );
        for (final item in otherLetters) {
          if (item.scriptKind == KanaScriptKind.hiragana &&
              !options.contains(item.kanaChar)) {
            options.add(item.kanaChar);
          }
          if (options.length >= 4) {
            break;
          }
        }
        break;
      case ReviewQuestionType.romajiToKatakana:
      case ReviewQuestionType.hiraganaToKatakana:
        options.add(
          questionType == ReviewQuestionType.romajiToKatakana
              ? letter.kanaChar
              : counterpart?.kanaChar ?? letter.kanaChar,
        );
        for (final item in otherLetters) {
          if (item.scriptKind == KanaScriptKind.katakana &&
              !options.contains(item.kanaChar)) {
            options.add(item.kanaChar);
          }
          if (options.length >= 4) {
            break;
          }
        }
        break;
    }

    if (options.length < 4) {
      for (final item in otherLetters) {
        if (!options.contains(item.kanaChar)) {
          options.add(item.kanaChar);
        }
        if (options.length >= 4) {
          break;
        }
      }
    }

    return _stableShuffle(
      options.take(4).toList(),
      _simpleHash('$userId:${letter.id}:${questionType.name}').abs(),
    );
  }

  KanaLetter? _resolveKanaCounterpart(
    KanaLetter letter,
    List<KanaLetter> allLetters,
  ) {
    if (letter.pairGroupId == null) {
      return null;
    }

    final targetKind = letter.scriptKind == KanaScriptKind.hiragana
        ? KanaScriptKind.katakana
        : KanaScriptKind.hiragana;
    for (final candidate in allLetters) {
      if (candidate.pairGroupId == letter.pairGroupId &&
          candidate.scriptKind == targetKind) {
        return candidate;
      }
    }
    return null;
  }

  List<String> _stableShuffle(List<String> values, int seed) {
    final result = List<String>.from(values);
    final random = Random(seed);
    for (var index = result.length - 1; index > 0; index--) {
      final swapIndex = random.nextInt(index + 1);
      final current = result[index];
      result[index] = result[swapIndex];
      result[swapIndex] = current;
    }
    return result;
  }

  int _simpleHash(String value) {
    var hash = 0;
    for (var index = 0; index < value.length; index++) {
      hash = ((hash << 5) - hash) + value.codeUnitAt(index);
      hash |= 0;
    }
    return hash;
  }
}
