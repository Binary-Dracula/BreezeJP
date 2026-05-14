import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

class WordStateUpsert {
  const WordStateUpsert({
    required this.wordId,
    required this.bookId,
    required this.userState,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.firstLearnedAt,
    this.interval,
    this.easeFactor,
    this.stability,
    this.difficulty,
    this.streak,
    this.totalReviews,
    this.failCount,
    this.version,
  });

  final String wordId;
  final String bookId;
  final int userState;
  final int? nextReviewAt;
  final int? lastReviewedAt;
  final int? firstLearnedAt;
  final int? interval;
  final double? easeFactor;
  final double? stability;
  final double? difficulty;
  final int? streak;
  final int? totalReviews;
  final int? failCount;
  final int? version;

  Map<String, dynamic> toJson() {
    return {
      'word_id': wordId,
      'book_id': bookId,
      'user_state': userState,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (firstLearnedAt != null) 'first_learned_at': firstLearnedAt,
      if (interval != null) 'interval': interval,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (streak != null) 'streak': streak,
      if (totalReviews != null) 'total_reviews': totalReviews,
      if (failCount != null) 'fail_count': failCount,
      if (version != null) 'version': version,
    };
  }
}

class WordRemoteCommand {
  final _dio = DioClient.instance.dio;

  Future<void> saveState(WordStateUpsert state) async {
    await _dio.post<void>(ApiEndpoints.wordStates, data: state.toJson());
  }

  Future<void> saveStates(List<WordStateUpsert> states) async {
    if (states.isEmpty) {
      return;
    }

    if (states.length == 1) {
      await saveState(states.first);
      return;
    }

    await _dio.post<void>(
      ApiEndpoints.wordStates,
      data: {'states': states.map((state) => state.toJson()).toList()},
    );
  }
}
