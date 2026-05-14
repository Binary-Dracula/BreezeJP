import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_remote_query.dart';
import 'home_remote_query_provider.dart';

final homeQueryProvider = Provider<HomeQuery>((ref) {
  return HomeQuery(ref.read(homeRemoteQueryProvider));
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
  HomeQuery(this._homeRemoteQuery);

  final HomeRemoteQuery _homeRemoteQuery;

  Future<HomeSummaryData> fetchHomeSummary() async {
    final summary = await _homeRemoteQuery.fetchHomeSummary();

    return HomeSummaryData(
      userName: summary.userName,
      reviewCount: summary.reviewCount,
      kanaReviewCount: summary.kanaReviewCount,
      masteredWordCount: summary.masteredWordCount,
    );
  }
}
