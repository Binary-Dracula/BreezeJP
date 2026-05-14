import '../../core/constants/learning_status.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_letter.dart';
import '../models/read/example_favorite_item.dart';
import '../models/read/grammar_book_item.dart';
import '../models/read/vocabulary_book_item.dart';
import '../models/study_word.dart';
import '../models/word_detail.dart';

class StudyRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<RemoteWordReviewSession> createWordReviewSession({
    required int localUserId,
    int limit = 20,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.reviewSessions,
      data: {'kind': 'word', 'limit': limit},
    );
    return RemoteWordReviewSession.fromApiData(
      response.data!['data'],
      localUserId,
    );
  }

  Future<RemoteKanaReviewSession> createKanaReviewSession({
    required int localUserId,
    int limit = 20,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.reviewSessions,
      data: {'kind': 'kana', 'limit': limit},
    );
    return RemoteKanaReviewSession.fromApiData(
      response.data!['data'],
      localUserId,
    );
  }

  Future<RemotePagedItems<VocabularyBookItem>> fetchWordBook({
    required LearningStatus status,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.wordBook,
      queryParameters: {
        'status': _wordStatusParam(status),
        'limit': limit,
        'offset': offset,
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
      },
    );
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? const {};
    return RemotePagedItems(
      items: data
          .map(
            (item) => VocabularyBookItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      totalCount: (meta['total_count'] as int?) ?? 0,
      hasMore: meta['has_more'] == true,
    );
  }

  Future<RemotePagedItems<VocabularyBookItem>> fetchWordFavorites({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.wordBook,
      queryParameters: {
        'status': 'favorite',
        'limit': limit,
        'offset': offset,
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
      },
    );
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? const {};
    return RemotePagedItems(
      items: data
          .map(
            (item) => VocabularyBookItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      totalCount: (meta['total_count'] as int?) ?? 0,
      hasMore: meta['has_more'] == true,
    );
  }

  Future<RemotePagedItems<ExampleFavoriteItem>> fetchWordExampleFavorites({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.exampleFavorites,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
      },
    );
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? const {};
    return RemotePagedItems(
      items: data
          .map(
            (item) => ExampleFavoriteItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      totalCount: (meta['total_count'] as int?) ?? 0,
      hasMore: meta['has_more'] == true,
    );
  }

  Future<RemotePagedItems<GrammarBookItem>> fetchGrammarBook({
    required LearningStatus status,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.grammarBook,
      queryParameters: {
        'status': _grammarStatusParam(status),
        'limit': limit,
        'offset': offset,
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
      },
    );
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? const {};
    return RemotePagedItems(
      items: data
          .map(
            (item) => GrammarBookItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      totalCount: (meta['total_count'] as int?) ?? 0,
      hasMore: meta['has_more'] == true,
    );
  }

  String _wordStatusParam(LearningStatus status) {
    switch (status) {
      case LearningStatus.learning:
        return 'learning';
      case LearningStatus.mastered:
        return 'mastered';
      case LearningStatus.ignored:
        return 'ignored';
      case LearningStatus.unlearned:
        return 'learning';
    }
  }

  String _grammarStatusParam(LearningStatus status) {
    switch (status) {
      case LearningStatus.mastered:
        return 'mastered';
      case LearningStatus.learning:
      case LearningStatus.unlearned:
      case LearningStatus.ignored:
        return 'learning';
    }
  }
}

class RemotePagedItems<T> {
  const RemotePagedItems({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });

  final List<T> items;
  final int totalCount;
  final bool hasMore;
}

class RemoteWordReviewSession {
  const RemoteWordReviewSession({
    required this.sessionId,
    required this.currentIndex,
    required this.items,
  });

  final String? sessionId;
  final int currentIndex;
  final List<RemoteWordReviewSessionItem> items;

  const RemoteWordReviewSession.empty()
    : sessionId = null,
      currentIndex = 0,
      items = const [];

  factory RemoteWordReviewSession.fromApiData(dynamic data, int localUserId) {
    if (data is List) {
      return const RemoteWordReviewSession.empty();
    }
    if (data is Map) {
      return RemoteWordReviewSession.fromJson(
        Map<String, dynamic>.from(data),
        localUserId,
      );
    }
    return const RemoteWordReviewSession.empty();
  }

  factory RemoteWordReviewSession.fromJson(
    Map<String, dynamic> json,
    int localUserId,
  ) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map(
          (item) => RemoteWordReviewSessionItem.fromJson(
            Map<String, dynamic>.from(item as Map),
            localUserId,
          ),
        )
        .toList();

    return RemoteWordReviewSession(
      sessionId: _asNullableString(json['session_id']),
      currentIndex: (json['current_index'] as int?) ?? 0,
      items: items,
    );
  }
}

class RemoteKanaReviewSession {
  const RemoteKanaReviewSession({
    required this.sessionId,
    required this.currentIndex,
    required this.items,
  });

  final String? sessionId;
  final int currentIndex;
  final List<RemoteKanaReviewSessionItem> items;

  const RemoteKanaReviewSession.empty()
    : sessionId = null,
      currentIndex = 0,
      items = const [];

  factory RemoteKanaReviewSession.fromApiData(dynamic data, int localUserId) {
    if (data is List) {
      return const RemoteKanaReviewSession.empty();
    }
    if (data is Map) {
      return RemoteKanaReviewSession.fromJson(
        Map<String, dynamic>.from(data),
        localUserId,
      );
    }
    return const RemoteKanaReviewSession.empty();
  }

  factory RemoteKanaReviewSession.fromJson(
    Map<String, dynamic> json,
    int localUserId,
  ) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map(
          (item) => RemoteKanaReviewSessionItem.fromJson(
            Map<String, dynamic>.from(item as Map),
            localUserId,
          ),
        )
        .toList();

    return RemoteKanaReviewSession(
      sessionId: _asNullableString(json['session_id']),
      currentIndex: (json['current_index'] as int?) ?? 0,
      items: items,
    );
  }
}

class RemoteWordReviewSessionItem {
  const RemoteWordReviewSessionItem({
    required this.studyWord,
    required this.wordDetail,
    required this.questionType,
    required this.audioSource,
    required this.meaning,
    required this.reading,
    required this.options,
    this.clozeSentence,
  });

  final StudyWord studyWord;
  final WordDetail wordDetail;
  final String questionType;
  final String? audioSource;
  final String? meaning;
  final String? reading;
  final List<String> options;

  /// 仅 cloze_test 题型携带：例句（目标单词已替换为 ___）
  final String? clozeSentence;

  factory RemoteWordReviewSessionItem.fromJson(
    Map<String, dynamic> json,
    int localUserId,
  ) {
    final state = Map<String, dynamic>.from(json['word_state'] as Map);
    return RemoteWordReviewSessionItem(
      studyWord: StudyWord(
        id: 0,
        userId: localUserId,
        wordId: _asNullableString(state['word_id']) ?? '',
        bookId: _asNullableString(state['book_id']) ?? '',
        userState: LearningStatus.fromValue((state['user_state'] as int?) ?? 1),
        nextReviewAt: _secondsToDateTime(state['next_review_at'] as int?),
        lastReviewedAt: _secondsToDateTime(state['last_reviewed_at'] as int?),
        firstLearnedAt: _secondsToDateTime(state['first_learned_at'] as int?),
        interval: state['interval'] as int?,
        easeFactor: (state['ease_factor'] as num?)?.toDouble(),
        stability: (state['stability'] as num?)?.toDouble(),
        difficulty: (state['difficulty'] as num?)?.toDouble(),
        streak: (state['streak'] as int?) ?? 0,
        totalReviews: (state['total_reviews'] as int?) ?? 0,
        failCount: (state['fail_count'] as int?) ?? 0,
        createdAt: _parseRemoteDateTime(state['created_at']) ?? DateTime.now(),
        updatedAt: _parseRemoteDateTime(state['updated_at']) ?? DateTime.now(),
      ),
      wordDetail: WordDetail.fromJson(
        Map<String, dynamic>.from(json['word_detail'] as Map),
      ),
      questionType:
          _asNullableString(json['question_type']) ?? 'word_to_meaning',
      audioSource: _asNullableString(json['audio_source']),
      meaning: _asNullableString(json['meaning']),
      reading: _asNullableString(json['reading']),
      options: _toStringList(json['options']),
      clozeSentence: _asNullableString(json['cloze_sentence']),
    );
  }
}

class RemoteKanaReviewSessionItem {
  const RemoteKanaReviewSessionItem({
    required this.kanaLetter,
    required this.learningState,
    required this.questionType,
    required this.options,
    this.audioFilename,
    this.counterpartLetter,
  });

  final KanaLetter kanaLetter;
  final KanaLearningState learningState;
  final String questionType;
  final List<String> options;
  final String? audioFilename;
  final KanaLetter? counterpartLetter;

  factory RemoteKanaReviewSessionItem.fromJson(
    Map<String, dynamic> json,
    int localUserId,
  ) {
    return RemoteKanaReviewSessionItem(
      kanaLetter: KanaLetter.fromMap(
        Map<String, dynamic>.from(json['kana_letter'] as Map),
      ),
      learningState: _kanaLearningStateFromJson(
        Map<String, dynamic>.from(json['learning_state'] as Map),
        localUserId,
      ),
      questionType:
          _asNullableString(json['question_type']) ?? 'hiragana_to_romaji',
      options: _toStringList(json['options']),
      audioFilename: _asNullableString(json['audio_filename']),
      counterpartLetter: json['counterpart_letter'] == null
          ? null
          : KanaLetter.fromMap(
              Map<String, dynamic>.from(json['counterpart_letter'] as Map),
            ),
    );
  }
}

DateTime? _secondsToDateTime(int? seconds) {
  if (seconds == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

KanaLearningState _kanaLearningStateFromJson(
  Map<String, dynamic> json,
  int localUserId,
) {
  final createdAt = _parseRemoteDateTime(json['created_at']);
  final updatedAt = _parseRemoteDateTime(json['updated_at']);

  return KanaLearningState.fromMap({
    'id': 0,
    'user_id': localUserId,
    'kana_id': json['kana_id'],
    'learning_status': json['learning_status'],
    'next_review_at': _readNullableInt(json['next_review_at']),
    'last_review_at': _readNullableInt(json['last_reviewed_at']),
    'last_reviewed_at': _readNullableInt(json['last_reviewed_at']),
    'streak': json['streak'],
    'total_reviews': json['total_reviews'],
    'fail_count': json['fail_count'],
    'interval': json['interval'],
    'ease_factor': json['ease_factor'],
    'stability': json['stability'],
    'difficulty': json['difficulty'],
    'created_at': createdAt?.millisecondsSinceEpoch != null
        ? createdAt!.millisecondsSinceEpoch ~/ 1000
        : null,
    'updated_at': updatedAt?.millisecondsSinceEpoch != null
        ? updatedAt!.millisecondsSinceEpoch ~/ 1000
        : null,
  });
}

int? _readNullableInt(dynamic value) {
  return switch (value) {
    null => null,
    int number => number,
    String text => int.tryParse(text),
    _ => null,
  };
}

DateTime? _parseIsoDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = value is String ? value.trim() : value.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

List<String> _toStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((entry) => _asNullableString(entry))
      .whereType<String>()
      .toList();
}

DateTime? _parseRemoteDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    final timestamp = value.toInt();
    if (timestamp <= 0) {
      return null;
    }
    final milliseconds = timestamp > 100000000000
        ? timestamp
        : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  final normalized = _asNullableString(value);
  if (normalized == null) {
    return null;
  }

  final numericTimestamp = int.tryParse(normalized);
  if (numericTimestamp != null) {
    return _parseRemoteDateTime(numericTimestamp);
  }

  return _parseIsoDateTime(normalized);
}
