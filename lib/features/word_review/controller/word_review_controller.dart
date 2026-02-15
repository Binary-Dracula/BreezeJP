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
import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

final wordReviewControllerProvider =
    NotifierProvider<WordReviewController, WordReviewState>(
      WordReviewController.new,
    );

class WordReviewController extends Notifier<WordReviewState> {
  static const int _windowSize = 4;

  int? _userId;
  bool _isResolvingSelection = false;
  final Set<int> _mistakeWordIds = {};

  List<WordReviewItem> _wordToMeaningGroup = [];
  List<WordReviewItem> _meaningToWordGroup = [];
  List<WordReviewItem> _audioToWordGroup = [];
  List<WordReviewItem> _readingToWordGroup = [];

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

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  void _clearTypeGroups() {
    _wordToMeaningGroup = [];
    _meaningToWordGroup = [];
    _audioToWordGroup = [];
    _readingToWordGroup = [];
    _mistakeWordIds.clear();
  }

  void _setSessionBootstrapState({
    required bool isLoading,
    required bool isEmpty,
  }) {
    state = state.copyWith(
      isLoading: isLoading,
      isEmpty: isEmpty,
      resetCurrentQuestionType: true,
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
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
        _clearTypeGroups();
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        logger.info('No due words for matching review.');
        return;
      }

      logger.info('Start word matching review: ${items.length} items');
      await startReview(items);
    } catch (e, stackTrace) {
      logger.error('Start word matching review failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startReview(List<WordReviewItem> reviewList) async {
    final wordToMeaning = <WordReviewItem>[];
    final meaningToWord = <WordReviewItem>[];
    final audioToWord = <WordReviewItem>[];
    final readingToWord = <WordReviewItem>[];

    for (final item in reviewList) {
      switch (item.questionType) {
        case WordReviewQuestionType.wordToMeaning:
          wordToMeaning.add(item);
          break;
        case WordReviewQuestionType.meaningToWord:
          meaningToWord.add(item);
          break;
        case WordReviewQuestionType.audioToWord:
          audioToWord.add(item);
          break;
        case WordReviewQuestionType.readingToWord:
          readingToWord.add(item);
          break;
      }
    }

    _wordToMeaningGroup = wordToMeaning;
    _meaningToWordGroup = meaningToWord;
    _audioToWordGroup = audioToWord;
    _readingToWordGroup = readingToWord;

    _setSessionBootstrapState(isLoading: true, isEmpty: false);

    try {
      await startNextGroup();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      logger.error('Start next word review group failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startGroup(
    WordReviewQuestionType type,
    List<WordReviewItem> groupItems,
  ) async {
    if (groupItems.isEmpty) {
      await startNextGroup();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isEmpty: false,
      currentQuestionType: type,
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      error: null,
    );

    try {
      final split = _buildInitialPairs(groupItems);
      final activePairs = split.activePairs;
      final remaining = split.remainingItems;

      if (activePairs.isEmpty && remaining.isEmpty) {
        await startNextGroup();
        return;
      }

      final rightOptions = _buildShuffledRightOptions(activePairs);

      state = state.copyWith(
        isLoading: false,
        activePairs: activePairs,
        remainingItems: remaining,
        rightOptions: rightOptions,
        selectedLeftIndex: null,
        selectedRightIndex: null,
        isGroupFinished: false,
        error: null,
      );
    } catch (e, stackTrace) {
      logger.error('Build word matching group failed', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectLeft(int index) async {
    if (_isResolvingSelection) return;
    if (index < 0 || index >= state.activePairs.length) return;
    if (state.activePairs[index].isMatched) return;

    final next = state.selectedLeftIndex == index ? null : index;
    state = state.copyWith(selectedLeftIndex: next, error: null);
    await _tryResolveSelection();
  }

  Future<void> selectRight(int rightIndex) async {
    if (_isResolvingSelection) return;
    if (rightIndex < 0 || rightIndex >= state.rightOptions.length) return;

    final option = state.rightOptions[rightIndex];
    if (option.pairIndex < 0 || option.pairIndex >= state.activePairs.length) {
      return;
    }
    if (state.activePairs[option.pairIndex].isMatched) return;

    final next = state.selectedRightIndex == rightIndex ? null : rightIndex;
    state = state.copyWith(selectedRightIndex: next, error: null);
    await _tryResolveSelection();
  }

  Future<void> _tryResolveSelection() async {
    if (_isResolvingSelection) return;

    final selectedLeftIndex = state.selectedLeftIndex;
    final selectedRightIndex = state.selectedRightIndex;
    if (selectedLeftIndex == null || selectedRightIndex == null) return;

    if (selectedLeftIndex < 0 ||
        selectedLeftIndex >= state.activePairs.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }
    if (selectedRightIndex < 0 ||
        selectedRightIndex >= state.rightOptions.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final rightPairIndex = state.rightOptions[selectedRightIndex].pairIndex;
    if (rightPairIndex < 0 || rightPairIndex >= state.activePairs.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final pair = state.activePairs[selectedLeftIndex];
    if (pair.isMatched) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final isCorrect = selectedLeftIndex == rightPairIndex;
    if (!isCorrect) {
      _mistakeWordIds.add(pair.item.studyWord.wordId);
      _isResolvingSelection = true;
      try {
        await Future.delayed(const Duration(milliseconds: 420));
        state = state.copyWith(
          selectedLeftIndex: null,
          selectedRightIndex: null,
          error: null,
        );
      } finally {
        _isResolvingSelection = false;
      }
      return;
    }

    _isResolvingSelection = true;
    try {
      await _handleCorrectMatch(pairIndex: selectedLeftIndex, pair: pair);
    } catch (e, stackTrace) {
      logger.error('Handle word match success failed', e, stackTrace);
      state = state.copyWith(error: e.toString());
    } finally {
      _isResolvingSelection = false;
    }
  }

  Future<void> _handleCorrectMatch({
    required int pairIndex,
    required WordReviewPair pair,
  }) async {
    final activePairs = List<WordReviewPair>.from(state.activePairs);
    if (pairIndex < 0 || pairIndex >= activePairs.length) return;

    final hadMistake = await _applyReviewResult(pair.item);

    final remaining = List<WordReviewItem>.from(state.remainingItems);
    if (hadMistake) {
      remaining.add(pair.item);
    }

    if (remaining.isNotEmpty) {
      activePairs.removeAt(pairIndex);
      final nextItem = remaining.removeAt(0);
      activePairs.insert(pairIndex, _pairForItem(nextItem));

      state = state.copyWith(
        activePairs: activePairs,
        remainingItems: remaining,
        rightOptions: _buildShuffledRightOptions(activePairs),
        selectedLeftIndex: null,
        selectedRightIndex: null,
        error: null,
      );
      return;
    }

    final current = activePairs[pairIndex];
    activePairs[pairIndex] = WordReviewPair(
      item: current.item,
      left: current.left,
      right: current.right,
      isMatched: true,
    );

    state = state.copyWith(
      activePairs: activePairs,
      selectedLeftIndex: null,
      selectedRightIndex: null,
      error: null,
    );

    if (remaining.isEmpty && activePairs.every((p) => p.isMatched)) {
      state = state.copyWith(isGroupFinished: true);
      await startNextGroup();
    }
  }

  ({List<WordReviewPair> activePairs, List<WordReviewItem> remainingItems})
  _buildInitialPairs(List<WordReviewItem> groupItems) {
    final activePairs = <WordReviewPair>[];
    final remaining = <WordReviewItem>[];

    for (final item in groupItems) {
      final pair = _pairForItem(item);
      final left = pair.left.trim();
      final right = pair.right.trim();
      final leftOk =
          item.questionType == WordReviewQuestionType.audioToWord ||
          left.isNotEmpty;

      if (!leftOk || right.isEmpty) {
        logger.warning(
          'Skip invalid word review item: wordId=${item.studyWord.wordId}'
          ' type=${item.questionType.name}',
        );
        continue;
      }

      if (activePairs.length < _windowSize) {
        activePairs.add(pair);
      } else {
        remaining.add(item);
      }
    }

    if (activePairs.isEmpty) {
      return (activePairs: const [], remainingItems: const []);
    }

    return (activePairs: activePairs, remainingItems: remaining);
  }

  WordReviewPair _pairForItem(WordReviewItem item) {
    return WordReviewPair(
      item: item,
      left: _leftValueForItem(item),
      right: _rightValueForItem(item),
      isMatched: false,
    );
  }

  List<WordReviewOption> _buildShuffledRightOptions(
    List<WordReviewPair> activePairs,
  ) {
    final options = <WordReviewOption>[
      for (var i = 0; i < activePairs.length; i++)
        WordReviewOption(pairIndex: i, value: activePairs[i].right),
    ];
    options.shuffle();
    return options;
  }

  Future<void> startNextGroup() async {
    WordReviewQuestionType? nextType;
    List<WordReviewItem> nextItems = [];

    if (state.currentQuestionType == null) {
      if (_wordToMeaningGroup.isNotEmpty) {
        nextType = WordReviewQuestionType.wordToMeaning;
        nextItems = _wordToMeaningGroup;
        _wordToMeaningGroup = [];
      } else if (_meaningToWordGroup.isNotEmpty) {
        nextType = WordReviewQuestionType.meaningToWord;
        nextItems = _meaningToWordGroup;
        _meaningToWordGroup = [];
      } else if (_audioToWordGroup.isNotEmpty) {
        nextType = WordReviewQuestionType.audioToWord;
        nextItems = _audioToWordGroup;
        _audioToWordGroup = [];
      } else if (_readingToWordGroup.isNotEmpty) {
        nextType = WordReviewQuestionType.readingToWord;
        nextItems = _readingToWordGroup;
        _readingToWordGroup = [];
      }
    } else {
      switch (state.currentQuestionType!) {
        case WordReviewQuestionType.wordToMeaning:
          if (_meaningToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.meaningToWord;
            nextItems = _meaningToWordGroup;
            _meaningToWordGroup = [];
          } else if (_audioToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.audioToWord;
            nextItems = _audioToWordGroup;
            _audioToWordGroup = [];
          } else if (_readingToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.readingToWord;
            nextItems = _readingToWordGroup;
            _readingToWordGroup = [];
          }
          break;
        case WordReviewQuestionType.meaningToWord:
          if (_audioToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.audioToWord;
            nextItems = _audioToWordGroup;
            _audioToWordGroup = [];
          } else if (_readingToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.readingToWord;
            nextItems = _readingToWordGroup;
            _readingToWordGroup = [];
          }
          break;
        case WordReviewQuestionType.audioToWord:
          if (_readingToWordGroup.isNotEmpty) {
            nextType = WordReviewQuestionType.readingToWord;
            nextItems = _readingToWordGroup;
            _readingToWordGroup = [];
          }
          break;
        case WordReviewQuestionType.readingToWord:
          break;
      }
    }

    if (nextType == null || nextItems.isEmpty) {
      await finishAll();
      return;
    }

    await startGroup(nextType, nextItems);
  }

  Future<void> finishAll() async {
    state = state.copyWith(
      isLoading: false,
      isAllFinished: true,
      isGroupFinished: true,
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
      resetCurrentQuestionType: true,
      selectedLeftIndex: null,
      selectedRightIndex: null,
    );
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
        studyWord.wordId,
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
      available.add(WordReviewQuestionType.meaningToWord);
    }
    if (audioSource != null && audioSource.isNotEmpty) {
      available.add(WordReviewQuestionType.audioToWord);
    }
    if (reading != null && reading.isNotEmpty) {
      available.add(WordReviewQuestionType.readingToWord);
    }
    return available;
  }

  WordReviewQuestionType _chooseQuestionType(
    int wordId,
    Set<WordReviewQuestionType> available,
  ) {
    const order = [
      WordReviewQuestionType.wordToMeaning,
      WordReviewQuestionType.meaningToWord,
      WordReviewQuestionType.audioToWord,
      WordReviewQuestionType.readingToWord,
    ];
    final startIndex = wordId % order.length;
    for (var i = 0; i < order.length; i++) {
      final type = order[(startIndex + i) % order.length];
      if (available.contains(type)) {
        return type;
      }
    }
    return available.first;
  }

  Future<bool> _applyReviewResult(WordReviewItem item) async {
    final hadMistake = _mistakeWordIds.remove(item.studyWord.wordId);
    final rating = hadMistake ? ReviewRating.again : ReviewRating.good;
    await _wordCommand.onWordReviewed(
      userId: item.studyWord.userId,
      wordId: item.studyWord.wordId,
      rating: rating,
    );
    return hadMistake;
  }

  String _leftValueForItem(WordReviewItem item) {
    switch (item.questionType) {
      case WordReviewQuestionType.wordToMeaning:
        return item.wordDetail.word.word;
      case WordReviewQuestionType.meaningToWord:
        return item.meaning ?? '';
      case WordReviewQuestionType.audioToWord:
        return '';
      case WordReviewQuestionType.readingToWord:
        return item.reading ?? '';
    }
  }

  String _rightValueForItem(WordReviewItem item) {
    switch (item.questionType) {
      case WordReviewQuestionType.wordToMeaning:
        return item.meaning ?? '';
      case WordReviewQuestionType.meaningToWord:
      case WordReviewQuestionType.audioToWord:
      case WordReviewQuestionType.readingToWord:
        return item.wordDetail.word.word;
    }
  }

  Future<void> endSession() async {
    return;
  }
}
