import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/learning_status.dart';
import '../models/vocab_book.dart';
import '../models/word_detail.dart';

/// 词汇远程查询服务
/// 负责从 Cloudflare Workers API 获取词汇相关数据
class VocabRemoteQuery {
  final _dio = DioClient.instance.dio;

  /// 获取当前所有可用辞书列表
  Future<BookListResponse> fetchBooks() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.books);
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? {};
    return BookListResponse(
      books: data
          .map((e) => VocabBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime:
          meta['server_time'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<RemoteWordLearnSession> createLearnSession({
    required String bookId,
    required int limit,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.learnSessions,
      data: {'book_id': bookId, 'limit': limit},
    );
    return RemoteWordLearnSession.fromJson(response.data!);
  }

  Future<void> completeLearnSession({
    required String sessionId,
    required List<LearnWordStateResult> wordStates,
    required int firstReviewIntervalMinutes,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.replaceParams(ApiEndpoints.learnSessionComplete, {
        'id': sessionId,
      }),
      data: {
        'word_states': wordStates.map((entry) => entry.toJson()).toList(),
        'first_review_interval_minutes': firstReviewIntervalMinutes,
      },
    );
  }
}

class BookListResponse {
  final List<VocabBook> books;
  final String serverTime;

  const BookListResponse({required this.books, required this.serverTime});
}

class RemoteWordLearnSession {
  const RemoteWordLearnSession({
    required this.sessionId,
    required this.bookId,
    required this.batchStartSort,
    required this.batchEndSort,
    required this.words,
    required this.totalWords,
    required this.resumed,
    required this.rawWordsJson,
  });

  final String? sessionId;
  final String bookId;
  final int batchStartSort;
  final int batchEndSort;
  final List<WordDetailWithSort> words;
  final int totalWords;
  final bool resumed;
  final List<Map<String, dynamic>> rawWordsJson;

  factory RemoteWordLearnSession.fromJson(Map<String, dynamic> json) {
    final payload = json['data'];
    if (payload is! Map) {
      throw const FormatException(
        'Invalid learn session payload: missing data',
      );
    }

    final data = Map<String, dynamic>.from(payload);
    final metaValue = json['meta'];
    final meta = metaValue is Map<String, dynamic>
        ? metaValue
        : metaValue is Map
        ? Map<String, dynamic>.from(metaValue)
        : const <String, dynamic>{};
    final rawWordsValue = data['words'];
    if (rawWordsValue != null && rawWordsValue is! List) {
      throw const FormatException(
        'Invalid learn session payload: words must be a list',
      );
    }
    final rawWords = (rawWordsValue as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final sessionId = _asNullableString(data['session_id']);
    if (rawWords.isNotEmpty && sessionId == null) {
      throw const FormatException(
        'Invalid learn session payload: non-empty words require session_id',
      );
    }

    return RemoteWordLearnSession(
      sessionId: sessionId,
      bookId: _asNullableString(data['book_id']) ?? '',
      batchStartSort: _asInt(data['batch_start_sort']) ?? 0,
      batchEndSort: _asInt(data['batch_end_sort']) ?? 0,
      words: rawWords.map(WordDetailWithSort.fromJson).toList(),
      totalWords: _asInt(meta['total_words']) ?? 0,
      resumed: meta['resumed'] == true,
      rawWordsJson: rawWords,
    );
  }
}

/// 附带 book_sort_order 的单词详情
class WordDetailWithSort {
  final WordDetail detail;
  final int bookSortOrder;

  WordDetailWithSort({required this.detail, required this.bookSortOrder});

  factory WordDetailWithSort.fromJson(Map<String, dynamic> json) {
    return WordDetailWithSort(
      detail: WordDetail.fromJson(json),
      bookSortOrder: (json['book_sort_order'] as int?) ?? 0,
    );
  }
}

class LearnWordStateResult {
  const LearnWordStateResult({required this.wordId, required this.userState});

  final String wordId;
  final LearningStatus userState;

  Map<String, dynamic> toJson() {
    return {'word_id': wordId, 'user_state': userState.value};
  }
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

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}
