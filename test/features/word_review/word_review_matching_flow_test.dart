import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breeze_jp/core/algorithm/srs_types.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_audio.dart';
import 'package:breeze_jp/data/models/word_choice.dart';
import 'package:breeze_jp/data/models/word_detail.dart';
import 'package:breeze_jp/data/models/word_meaning.dart';
import 'package:breeze_jp/data/models/word_with_relation.dart';
import 'package:breeze_jp/data/models/read/word_list_item.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_word_query.dart';
import 'package:breeze_jp/data/queries/study_word_query.dart';
import 'package:breeze_jp/data/queries/word_read_queries.dart';
import 'package:breeze_jp/features/word_review/controller/word_review_controller.dart';
import 'package:breeze_jp/features/word_review/state/word_review_item.dart';
import 'package:breeze_jp/features/word_review/state/word_review_state.dart';

class _FakeActiveUserCommand implements ActiveUserCommand {
  _FakeActiveUserCommand(this.user);

  final User user;

  @override
  Future<User> ensureActiveUser() async => user;

  @override
  Future<User> createAndActivateDefaultUser() async => user;

  @override
  Future<void> switchUser(int userId) async {
    if (userId != user.id) {
      throw StateError('Unexpected user switch: $userId');
    }
  }
}

class _FakeActiveUserQuery implements ActiveUserQuery {
  _FakeActiveUserQuery(this.user);

  final User user;

  @override
  Future<int?> getActiveUserId() async => user.id;

  @override
  Future<User?> getActiveUser() async => user;
}

class _FakeStudyWordQuery implements StudyWordQuery {
  _FakeStudyWordQuery(this.dueStates);

  final List<StudyWord> dueStates;

  @override
  Future<List<StudyWord>> getDueReviews(int userId, {int? limit}) async {
    return dueStates;
  }

  @override
  Future<int> getDueReviewCount(int userId) async => dueStates.length;

  @override
  Future<StudyWord?> getStudyWord(int userId, int wordId) async {
    for (final state in dueStates) {
      if (state.userId == userId && state.wordId == wordId) {
        return state;
      }
    }
    return null;
  }

  @override
  Future<List<StudyWord>> getUserStudyWords(
    int userId, {
    LearningStatus? state,
    int? limit,
    int? offset,
  }) async {
    return dueStates;
  }

  @override
  Future<List<StudyWord>> getNewWords(int userId, {int? limit}) async {
    return const [];
  }
}

class _FakeWordReadQueries implements WordReadQueries {
  _FakeWordReadQueries(this.detailsById);

  final Map<int, WordDetail> detailsById;

  @override
  Ref get ref => throw UnimplementedError('ref not needed in this test.');

  @override
  Future<WordDetail?> getWordDetail(int wordId) async {
    return detailsById[wordId];
  }

  @override
  Future<List<WordListItem>> getWordListItems({
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    throw UnimplementedError('getWordListItems not needed in this test.');
  }

  @override
  Future<List<Word>> getWordsByLevel({
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    throw UnimplementedError('getWordsByLevel not needed in this test.');
  }

  @override
  Future<List<Word>> searchWords({
    required String keyword,
    int? limit,
  }) async {
    throw UnimplementedError('searchWords not needed in this test.');
  }

  @override
  Future<List<Word>> getRandomWords({int limit = 10}) async {
    throw UnimplementedError('getRandomWords not needed in this test.');
  }

  @override
  Future<List<Word>> getUnlearnedWords({
    required int userId,
    int limit = 20,
    List<int> excludeIds = const [],
  }) async {
    throw UnimplementedError('getUnlearnedWords not needed in this test.');
  }

  @override
  Future<List<WordChoice>> getRandomUnmasteredWordsWithMeaning({
    required int userId,
    int count = 5,
  }) async {
    throw UnimplementedError(
      'getRandomUnmasteredWordsWithMeaning not needed in this test.',
    );
  }

  @override
  Future<List<WordWithRelation>> getRelatedWords({
    required int userId,
    required int wordId,
  }) async {
    throw UnimplementedError('getRelatedWords not needed in this test.');
  }
}

class _ReviewCall {
  _ReviewCall(this.userId, this.wordId, this.rating);

  final int userId;
  final int wordId;
  final ReviewRating rating;
}

class _SpyWordCommand extends WordCommand {
  _SpyWordCommand(super.ref);

  final List<_ReviewCall> calls = [];

  @override
  Future<void> onWordReviewed({
    required int userId,
    required int wordId,
    required ReviewRating rating,
    int durationMs = 0,
    AlgorithmType? algorithmType,
  }) async {
    calls.add(_ReviewCall(userId, wordId, rating));
  }
}

StudyWord _studyWord(int userId, int wordId) {
  final now = DateTime(2024, 1, 1);
  return StudyWord(
    id: wordId,
    userId: userId,
    wordId: wordId,
    userState: LearningStatus.learning,
    nextReviewAt: now.subtract(const Duration(days: 1)),
    lastReviewedAt: null,
    interval: 1,
    easeFactor: 2.5,
    stability: 0,
    difficulty: 0,
    streak: 0,
    totalReviews: 0,
    failCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

WordDetail _wordDetail({
  required int wordId,
  required String wordText,
  String? meaning,
  String? furigana,
  String? romaji,
  String? audioUrl,
}) {
  return WordDetail(
    word: Word(id: wordId, word: wordText, furigana: furigana, romaji: romaji),
    meanings: meaning == null
        ? const []
        : [
            WordMeaning(
              id: wordId * 10,
              wordId: wordId,
              meaningCn: meaning,
              definitionOrder: 1,
            ),
          ],
    audios: audioUrl == null
        ? const []
        : [
            WordAudio(
              id: wordId * 10,
              wordId: wordId,
              audioFilename: 'audio_$wordId.mp3',
              audioUrl: audioUrl,
            ),
          ],
    examples: const [],
  );
}

void main() {
  test('word review matching uses hard after mistake and good otherwise',
      () async {
    const userId = 1;
    final user = User(
      id: userId,
      username: 'tester',
      passwordHash: 'x',
      nickname: 'tester',
      locale: 'zh',
      onboardingCompleted: 1,
    );

    final dueStates = [
      _studyWord(userId, 4),
      _studyWord(userId, 8),
    ];
    final details = {
      4: _wordDetail(
        wordId: 4,
        wordText: 'alpha',
        meaning: 'meaning a',
        furigana: 'a',
        audioUrl: 'https://example.com/a.mp3',
      ),
      8: _wordDetail(
        wordId: 8,
        wordText: 'bravo',
        meaning: 'meaning b',
        furigana: 'b',
        audioUrl: 'https://example.com/b.mp3',
      ),
    };

    late _SpyWordCommand spyCommand;

    final container = ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWithValue(
          _FakeActiveUserCommand(user),
        ),
        activeUserQueryProvider.overrideWithValue(_FakeActiveUserQuery(user)),
        studyWordQueryProvider.overrideWithValue(_FakeStudyWordQuery(dueStates)),
        wordReadQueriesProvider.overrideWithValue(_FakeWordReadQueries(details)),
        wordCommandProvider.overrideWith(
          (ref) => spyCommand = _SpyWordCommand(ref),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(wordReviewControllerProvider.notifier);
    await controller.loadReview();

    var state = container.read(wordReviewControllerProvider);
    expect(state.currentQuestionType, WordReviewQuestionType.wordToMeaning);
    expect(state.activePairs.length, 2);
    expect(state.activePairs.first.item.studyWord.wordId, 4);

    final wrongRightIndex = state.rightOptions.indexWhere(
      (option) => option.pairIndex != 0,
    );
    expect(wrongRightIndex, isNot(-1));
    await controller.selectLeft(0);
    await controller.selectRight(wrongRightIndex);

    state = container.read(wordReviewControllerProvider);
    expect(state.selectedLeftIndex, isNull);
    expect(state.selectedRightIndex, isNull);

    final correctRightIndex = state.rightOptions.indexWhere(
      (option) => option.pairIndex == 0,
    );
    expect(correctRightIndex, isNot(-1));
    await controller.selectLeft(0);
    await controller.selectRight(correctRightIndex);

    state = container.read(wordReviewControllerProvider);
    final nextPairIndex =
        state.activePairs.indexWhere((pair) => !pair.isMatched);
    final nextRightIndex = state.rightOptions.indexWhere(
      (option) => option.pairIndex == nextPairIndex,
    );
    expect(nextPairIndex, isNot(-1));
    expect(nextRightIndex, isNot(-1));
    await controller.selectLeft(nextPairIndex);
    await controller.selectRight(nextRightIndex);

    expect(spyCommand.calls.length, 2);
    final ratingByWordId = <int, ReviewRating>{
      for (final call in spyCommand.calls) call.wordId: call.rating,
    };
    expect(ratingByWordId[4], ReviewRating.hard);
    expect(ratingByWordId[8], ReviewRating.good);
  });

  test('word review falls back to meaning when audio and reading are missing',
      () async {
    const userId = 1;
    final user = User(
      id: userId,
      username: 'tester',
      passwordHash: 'x',
      nickname: 'tester',
      locale: 'zh',
      onboardingCompleted: 1,
    );

    final dueStates = [_studyWord(userId, 2)];
    final details = {
      2: _wordDetail(
        wordId: 2,
        wordText: 'charlie',
        meaning: 'meaning c',
      ),
    };

    final container = ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWithValue(
          _FakeActiveUserCommand(user),
        ),
        activeUserQueryProvider.overrideWithValue(_FakeActiveUserQuery(user)),
        studyWordQueryProvider.overrideWithValue(_FakeStudyWordQuery(dueStates)),
        wordReadQueriesProvider.overrideWithValue(_FakeWordReadQueries(details)),
        wordCommandProvider.overrideWith((ref) => _SpyWordCommand(ref)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(wordReviewControllerProvider.notifier);
    await controller.loadReview();

    final state = container.read(wordReviewControllerProvider);
    expect(state.currentQuestionType, WordReviewQuestionType.wordToMeaning);
    expect(state.activePairs.length, 1);
    expect(state.activePairs.first.left, 'charlie');
    expect(state.activePairs.first.right, 'meaning c');
  });
}
