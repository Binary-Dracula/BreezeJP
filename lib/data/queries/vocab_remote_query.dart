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
    final data = Map<String, dynamic>.from(json['data'] as Map);
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final rawWords = (data['words'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    return RemoteWordLearnSession(
      sessionId: _asNullableString(data['session_id']),
      bookId: _asNullableString(data['book_id']) ?? '',
      batchStartSort: (data['batch_start_sort'] as int?) ?? 0,
      batchEndSort: (data['batch_end_sort'] as int?) ?? 0,
      words: rawWords.map(WordDetailWithSort.fromJson).toList(),
      totalWords: (meta['total_words'] as int?) ?? 0,
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
