import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/algorithm/srs_types.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/word_command.dart';
import '../../../data/models/study_word.dart';
import '../../../data/models/user.dart';
import '../../../data/models/word_detail.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/study_word_query.dart';
import '../../../data/queries/word_read_queries.dart';
import 'dart:math' as math;

import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

final wordReviewControllerProvider =
    NotifierProvider<WordReviewController, WordReviewState>(
      WordReviewController.new,
    );

class WordReviewController extends Notifier<WordReviewState> {
  final Set<String> _mistakeWordIds = {};

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyWordQuery get _studyWordQuery => ref.read(studyWordQueryProvider);
  WordReadQueries get _wordReadQueries => ref.read(wordReadQueriesProvider);
  WordCommand get _wordCommand => ref.read(wordCommandProvider);

  @override
  WordReviewState build() => const WordReviewState();

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
      _mistakeWordIds.clear();

      final user = await _getActiveUser();
      final dueStates = await _studyWordQuery.getDueReviews(user.id);

      final items = await _composeReviewItems(dueStates);
      if (items.isEmpty) {
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        logger.info('No due words for review.');
        return;
      }

      logger.info('Start single card review: ${items.length} items');

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
      logger.error('Start word review failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 为当前卡片生成四选一选项
  Future<void> _prepareCurrentCardOptions() async {
    final item = state.currentItem;
    if (item == null) return;

    // 从本地词库随机取干扰项
    final distractors = await _wordReadQueries.searchWords(
      keyword: '',
      limit: 10,
    );

    final options = <String>[];
    String correctOption = '';

    switch (item.questionType) {
      case WordReviewQuestionType.meaningToSpelling:
        final correctReading = item.reading ?? '';
        final chars = correctReading.split('');
        options.addAll(chars);
        final distractorsChars = [
          'あ',
          'い',
          'う',
          'え',
          'お',
          'か',
          'き',
          'く',
          'け',
          'こ',
          'が',
          'ぎ',
          'ぐ',
          'げ',
          'ご',
          'さ',
          'し',
          'す',
          'せ',
          'そ',
          'ざ',
          'じ',
          'ず',
          'ぜ',
          'ぞ',
          'た',
          'ち',
          'つ',
          'て',
          'と',
          'だ',
          'ぢ',
          'づ',
          'で',
          'ど',
          'な',
          'に',
          'ぬ',
          'ね',
          'の',
          'は',
          'ひ',
          'ふ',
          'へ',
          'ほ',
          'ば',
          'び',
          'ぶ',
          'べ',
          'ぼ',
          'ぱ',
          'ぴ',
          'ぷ',
          'ぺ',
          'ぽ',
          'ま',
          'み',
          'む',
          'め',
          'も',
          'や',
          'ゆ',
          'よ',
          'ら',
          'り',
          'る',
          'れ',
          'ろ',
          'わ',
          'を',
          'ん',
        ];
        distractorsChars.shuffle();
        for (var i = 0; i < 4; i++) {
          options.add(distractorsChars[i]);
        }
        break;
      case WordReviewQuestionType.wordToMeaning:
      case WordReviewQuestionType.audioToMeaning:
        correctOption = item.meaning ?? 'Unknown';
        options.add(correctOption);
        for (final d in distractors) {
          final m = d.primaryMeaning;
          if (m != null && m.isNotEmpty && !options.contains(m)) {
            options.add(m);
          }
          if (options.length >= 4) break;
        }
        break;
      case WordReviewQuestionType.kanjiToReading:
        correctOption = item.reading ?? '';
        options.add(correctOption);
        for (final d in distractors) {
          final r = d.reading.trim();
          if (r.isNotEmpty && !options.contains(r)) {
            options.add(r);
          }
          if (options.length >= 4) break;
        }
        break;
    }

    // 补足选项
    if (item.questionType != WordReviewQuestionType.meaningToSpelling &&
        options.length < 4) {
      final allItems = state.items;
      final otherItems = allItems
          .where((i) => i.studyWord.wordId != item.studyWord.wordId)
          .toList();
      otherItems.shuffle();
      for (final o in otherItems) {
        if (options.length >= 4) break;
        String val = '';
        if (item.questionType == WordReviewQuestionType.wordToMeaning ||
            item.questionType == WordReviewQuestionType.audioToMeaning) {
          val = o.meaning ?? '';
        } else if (item.questionType == WordReviewQuestionType.kanjiToReading) {
          val = o.reading ?? '';
        }
        if (val.isNotEmpty && !options.contains(val)) {
          options.add(val);
        }
      }
    }

    options.shuffle();
    state = state.copyWith(currentOptions: options);
  }

  /// 用户在客观测试中选择了某个选项
  Future<void> submitObjectiveAnswer(String selectedOption) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.testing) return;

    String correctOption = '';
    switch (item.questionType) {
      case WordReviewQuestionType.wordToMeaning:
      case WordReviewQuestionType.audioToMeaning:
        correctOption = item.meaning ?? 'Unknown';
        break;
      case WordReviewQuestionType.kanjiToReading:
      case WordReviewQuestionType.meaningToSpelling:
        correctOption = item.reading ?? '';
        break;
    }

    final isCorrect = selectedOption == correctOption;

    if (isCorrect) {
      state = state.copyWith(currentPhase: ReviewCardPhase.grading);
    } else {
      if (!state.hasMistakeOnCurrent) {
        state = state.copyWith(hasMistakeOnCurrent: true);
        _mistakeWordIds.add(item.studyWord.wordId);

        try {
          await _wordCommand.onWordReviewed(
            userId: item.studyWord.userId,
            wordId: item.studyWord.wordId,
            bookId: item.studyWord.bookId,
            rating: ReviewRating.again,
          );
        } catch (e, stackTrace) {
          logger.error('Failed to log again rating', e, stackTrace);
        }
      }
    }
  }

  /// 用户在主观评价中点击了 Hard/Good/Easy
  Future<void> submitSubjectiveRating(ReviewRating selectedRating) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.grading) return;

    try {
      if (!state.hasMistakeOnCurrent) {
        await _wordCommand.onWordReviewed(
          userId: item.studyWord.userId,
          wordId: item.studyWord.wordId,
          bookId: item.studyWord.bookId,
          rating: selectedRating,
        );
      }
    } catch (e, stackTrace) {
      logger.error('Failed to log rating', e, stackTrace);
    }

    await _goToNextCard();
  }

  Future<void> _goToNextCard() async {
    final items = List<WordReviewItem>.from(state.items);
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

  Future<void> finishAll() async {
    state = state.copyWith(isLoading: false, isAllFinished: true);
  }

  Future<List<WordReviewItem>> _composeReviewItems(
    List<StudyWord> studyWords,
  ) async {
    final items = <WordReviewItem>[];

    for (final studyWord in studyWords) {
      final WordDetail? detail = await _wordReadQueries.getWordDetail(
        studyWord.wordId,
      );
      if (detail == null) {
        logger.warning('Word not found for review: wordId=${studyWord.wordId}');
        continue;
      }

      final meaning = detail.primaryMeaning;
      final reading = _readingText(detail);
      final availableTypes = _availableTypes(
        meaning: meaning,
        reading: reading,
      );

      if (availableTypes.isEmpty) {
        logger.warning(
          'Skip word without review content: wordId=${studyWord.wordId}',
        );
        continue;
      }

      final questionType = _chooseQuestionType(
        studyWord,
        detail.word.word,
        availableTypes,
      );

      items.add(
        WordReviewItem(
          studyWord: studyWord,
          wordDetail: detail,
          questionType: questionType,
          audioSource: null,
          meaning: meaning,
          reading: reading,
        ),
      );
    }
    return items;
  }

  String? _readingText(WordDetail detail) {
    final reading = detail.word.reading.trim();
    if (reading.isNotEmpty) return reading;
    final romaji = detail.word.romaji?.trim() ?? '';
    return romaji.isNotEmpty ? romaji : null;
  }

  Set<WordReviewQuestionType> _availableTypes({
    required String? meaning,
    required String? reading,
  }) {
    final available = <WordReviewQuestionType>{};
    if (meaning != null && meaning.isNotEmpty) {
      available.add(WordReviewQuestionType.wordToMeaning);
      available.add(WordReviewQuestionType.meaningToSpelling);
    }
    if (reading != null && reading.isNotEmpty) {
      available.add(WordReviewQuestionType.kanjiToReading);
    }
    return available;
  }

  WordReviewQuestionType _chooseQuestionType(
    StudyWord studyWord,
    String wordStr,
    Set<WordReviewQuestionType> available,
  ) {
    final isNew = studyWord.totalReviews == 0;
    final r = math.Random().nextDouble();

    if (isNew) {
      if (r < 0.7 && available.contains(WordReviewQuestionType.wordToMeaning)) {
        return WordReviewQuestionType.wordToMeaning;
      }
      if (available.contains(WordReviewQuestionType.wordToMeaning)) {
        return WordReviewQuestionType.wordToMeaning;
      }
      return available.first;
    } else {
      if (r < 0.4 &&
          available.contains(WordReviewQuestionType.kanjiToReading) &&
          RegExp(r'[\u4e00-\u9faf]').hasMatch(wordStr)) {
        return WordReviewQuestionType.kanjiToReading;
      }
      if (available.contains(WordReviewQuestionType.meaningToSpelling)) {
        return WordReviewQuestionType.meaningToSpelling;
      }
      return available.first;
    }
  }

  Future<void> endSession() async {
    return;
  }
}
