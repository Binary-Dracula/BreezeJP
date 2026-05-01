import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_user_query.dart';
import 'active_user_query_provider.dart';
import 'kana_query.dart';
import 'kana_query_provider.dart';
import 'mastered_count_query.dart';
import 'study_word_query.dart';

final homeQueryProvider = Provider<HomeQuery>((ref) {
  return HomeQuery(
    ref.read(activeUserQueryProvider),
    ref.read(studyWordQueryProvider),
    ref.read(kanaQueryProvider),
    ref.read(masteredStateQueryProvider),
  );
});

class HomeSummaryData {
  const HomeSummaryData({
    required this.userName,
    required this.reviewCount,
    required this.kanaReviewCount,
    required this.masteredWordCount,
  });

  final String userName;
  final int reviewCount;
  final int kanaReviewCount;
  final int masteredWordCount;
}

class HomeQuery {
  HomeQuery(
    this._activeUserQuery,
    this._studyWordQuery,
    this._kanaQuery,
    this._masteredStateQuery,
  );

  final ActiveUserQuery _activeUserQuery;
  final StudyWordQuery _studyWordQuery;
  final KanaQuery _kanaQuery;
  final MasteredStateQuery _masteredStateQuery;

  Future<HomeSummaryData> fetchHomeSummary() async {
    final user = await _activeUserQuery.getActiveUser();

    if (user == null) {
      return const HomeSummaryData(
        userName: '',
        reviewCount: 0,
        kanaReviewCount: 0,
        masteredWordCount: 0,
      );
    }

    final counts = await Future.wait<int>([
      _studyWordQuery.getDueReviewCount(user.id),
      _kanaQuery.countDueKanaReviews(user.id),
      _masteredStateQuery.getWordMasteredCount(user.id),
    ]);

    final preferredName = user.nickname?.trim();
    final userName = preferredName != null && preferredName.isNotEmpty
        ? preferredName
        : user.username.trim();

    return HomeSummaryData(
      userName: userName,
      reviewCount: counts[0],
      kanaReviewCount: counts[1],
      masteredWordCount: counts[2],
    );
  }
}
