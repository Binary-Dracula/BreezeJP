import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/word_command.dart';
import '../../../data/models/study_log.dart';
import '../../../data/models/study_word.dart';
import '../../../data/models/user.dart';
import '../../../data/models/word_audio.dart';
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
  final Set<int> _mistakeWordIds = {};

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
      logger.error('Start word review failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 为当前卡片生成客观测试用的选项（例如四选一的意思或假名）
  Future<void> _prepareCurrentCardOptions() async {
    final item = state.currentItem;
    if (item == null) return;

    // 修正：干扰项从“表内所有数据”随机获取，而非仅从本次复习队列中获取
    final distractors = await _wordReadQueries.getRandomWordListItems(
      limit: 3,
      excludeIds: [item.studyWord.wordId],
    );

    final options = <String>[];
    String correctOption = '';

    switch (item.questionType) {
      case WordReviewQuestionType.meaningToSpelling:
        // 拼写题型不需要四个整词选项，而是把该单词自身的正确读音（例如：あたらしい）
        // 拆解成一个个假名，并混入一定量的干扰假名（如包含浊音、拗音的混淆项），
        // 最终在 UI 层生成一个“乱序的单字候选列表”。因此在这里给出一个标识即可，或者在此生成乱序集合。
        // 这里生成当前单词所有正确的假名词块，再从库里随机抽取几个常见假名作为干扰
        final correctReading = item.reading ?? '';
        final chars = correctReading.split('');
        options.addAll(chars);
        // 加入一些随机假名干扰项
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
        }
        break;
      case WordReviewQuestionType.kanjiToReading:
        correctOption = item.reading ?? '';
        options.add(correctOption);
        for (final d in distractors) {
          final r = d.word.furigana?.trim() ?? d.word.romaji?.trim() ?? '';
          if (r.isNotEmpty && !options.contains(r)) {
            options.add(r);
          }
        }
        break;
    }

    // 补足选项不足的逻辑 (如果不涉及 options 生成的题型可以跳过)
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

  /// 用户在阶段一（客观测试）中选择了某个选项
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
      // 进入阶段二：客观验证通过，展现详细信息以及主观评分按钮
      state = state.copyWith(currentPhase: ReviewCardPhase.grading);
    } else {
      // 答错处理
      // 记录这词这遍错了，必须进入再次复习队列，并且当即向算法发射一次 Again (1)
      if (!state.hasMistakeOnCurrent) {
        state = state.copyWith(hasMistakeOnCurrent: true);
        _mistakeWordIds.add(item.studyWord.wordId);

        try {
          // 直接下放 Again 评价罚分
          await _wordCommand.onWordReviewed(
            userId: item.studyWord.userId,
            wordId: item.studyWord.wordId,
            rating: ReviewRating.again,
            updateDailyStat: false,
          );
        } catch (e, stackTrace) {
          logger.error('Failed to log again rating', e, stackTrace);
        }
      }
      // 此处可以不立即切走，让前端摇晃或标红，用户必须去点一个跳过或者蒙对才能过
    }
  }

  /// 用户在阶段二（主观评价）点击了 Hard/Good/Easy
  Future<void> submitSubjectiveRating(ReviewRating selectedRating) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.grading) return;

    // 如果这个词刚才已经粗心答错过被发配为 Again 了，理论上这里再选 Easy 也救不回来。
    // 但是如果用户就是不小心点错，他如果在阶段二选了某值，我们应重新覆盖一次或者直接忽略。
    // 按标准 SRS：一次卡片周期如果发生了 Lapse(错)，这卡片就是 lapsed。
    // 如果 hasMistakeOnCurrent == false，说明他一次答对，正常吃下这个选的评分。
    try {
      if (!state.hasMistakeOnCurrent) {
        await _wordCommand.onWordReviewed(
          userId: item.studyWord.userId,
          wordId: item.studyWord.wordId,
          rating: selectedRating,
        );
      }
    } catch (e, stackTrace) {
      logger.error('Failed to log rating', e, stackTrace);
    }

    await _goToNextCard();
  }

  Future<void> _goToNextCard() async {
    // 如果当前词错了，我们需要把它重新塞回队列末尾（或者错题集中）强制重做
    final items = List<WordReviewItem>.from(state.items);
    if (state.hasMistakeOnCurrent) {
      final currentItem = items[state.currentIndex];
      items.add(currentItem); // 直接追加到队尾
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= items.length) {
      // 没有任何剩余卡片
      state = state.copyWith(
        isAllFinished: true,
        items: items,
        currentIndex: nextIndex,
      );
    } else {
      // 继续下一张
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

      final meaning = _primaryMeaning(detail);
      final reading = _readingText(detail);
      final audioSource = _resolveAudioSource(detail.primaryAudio);
      final availableTypes = _availableTypes(
        meaning: meaning,
        reading: reading,
        audioSource: audioSource,
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
          audioSource: audioSource,
          meaning: meaning,
          reading: reading,
        ),
      );
    }

    return items;
  }

  String? _primaryMeaning(WordDetail detail) {
    final meaning = detail.primaryMeaning?.trim() ?? '';
    return meaning.isEmpty ? null : meaning;
  }

  String? _readingText(WordDetail detail) {
    final furigana = detail.word.furigana?.trim() ?? '';
    if (furigana.isNotEmpty) return furigana;
    final romaji = detail.word.romaji?.trim() ?? '';
    return romaji.isNotEmpty ? romaji : null;
  }

  String? _resolveAudioSource(WordAudio? audio) {
    if (audio == null) return null;
    final url = audio.audioUrl?.trim() ?? '';
    if (url.isNotEmpty) return url;
    final filename = audio.audioFilename.trim();
    if (filename.isEmpty) return null;
    return _normalizeWordAudioPath(filename);
  }

  String _normalizeWordAudioPath(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('assets/')) return value;
    if (value.endsWith('.mp3') ||
        value.endsWith('.wav') ||
        value.endsWith('.m4a')) {
      return 'assets/audio/words/$value';
    }
    return 'assets/audio/words/$value.mp3';
  }

  Set<WordReviewQuestionType> _availableTypes({
    required String? meaning,
    required String? reading,
    required String? audioSource,
  }) {
    final available = <WordReviewQuestionType>{};
    if (meaning != null && meaning.isNotEmpty) {
      available.add(WordReviewQuestionType.wordToMeaning);
      available.add(WordReviewQuestionType.meaningToSpelling);
    }
    if (audioSource != null &&
        audioSource.isNotEmpty &&
        meaning != null &&
        meaning.isNotEmpty) {
      available.add(WordReviewQuestionType.audioToMeaning);
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
    final isNew = studyWord.totalReviews == 0 || studyWord.isNew;
    final r = math.Random().nextDouble();

    if (isNew) {
      if (r < 0.7 && available.contains(WordReviewQuestionType.wordToMeaning)) {
        return WordReviewQuestionType.wordToMeaning;
      }
      if (available.contains(WordReviewQuestionType.audioToMeaning)) {
        return WordReviewQuestionType.audioToMeaning;
      }
      return WordReviewQuestionType.wordToMeaning;
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
