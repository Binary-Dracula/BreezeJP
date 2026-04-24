import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/vocab_book.dart';
import '../models/word_detail.dart';

/// 词汇远程查询服务
/// 负责从 Cloudflare Workers API 获取词汇同步数据
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

  /// 增量同步辞书列表状态。
  Future<BookSyncResponse> fetchBookSync({required String since}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.bookSync,
      queryParameters: {'since': since},
    );
    final data = response.data!['data'] as List<dynamic>;
    final meta = response.data!['meta'] as Map<String, dynamic>? ?? {};
    return BookSyncResponse(
      books: data
          .map((e) => VocabBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime:
          meta['server_time'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// 获取书中下一批单词（按 book_sort_order 排列，含完整详情）
  ///
  /// 返回包含 book_sort_order 的完整词条列表，以及是否还有更多词
  Future<NextWordsResponse> fetchNextWords({
    required String bookId,
    required int afterSort,
    required int limit,
  }) async {
    final path = ApiEndpoints.replaceParams(ApiEndpoints.bookNextWords, {
      'bookId': bookId,
    });
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'after_sort': afterSort, 'limit': limit},
    );
    return NextWordsResponse.fromJson(response.data!);
  }
}

class BookListResponse {
  final List<VocabBook> books;
  final String serverTime;

  const BookListResponse({required this.books, required this.serverTime});
}

class BookSyncResponse {
  final List<VocabBook> books;
  final String serverTime;

  const BookSyncResponse({required this.books, required this.serverTime});
}

/// 下一批单词响应（含 book_sort_order）
class NextWordsResponse {
  final List<WordDetailWithSort> words;
  final bool hasMore;

  NextWordsResponse({required this.words, required this.hasMore});

  factory NextWordsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    return NextWordsResponse(
      words: data
          .map((e) => WordDetailWithSort.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: meta['has_more'] == true,
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
