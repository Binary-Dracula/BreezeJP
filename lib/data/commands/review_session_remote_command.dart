import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../features/kana/review/state/kana_review_state.dart';
import '../../features/word_review/state/word_review_state.dart';

final reviewSessionRemoteCommandProvider = Provider<ReviewSessionRemoteCommand>(
  (ref) {
    return ReviewSessionRemoteCommand();
  },
);

class ReviewSessionRemoteCommand {
  final _dio = DioClient.instance.dio;

  Future<void> completeWordSession({
    required String sessionId,
    required List<WordReviewAnsweredResult> results,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.replaceParams(ApiEndpoints.reviewSessionComplete, {
        'id': sessionId,
      }),
      data: {'results': results.map((result) => result.toJson()).toList()},
    );
  }

  Future<void> completeKanaSession({
    required String sessionId,
    required List<KanaReviewAnsweredResult> results,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.replaceParams(ApiEndpoints.reviewSessionComplete, {
        'id': sessionId,
      }),
      data: {'results': results.map((result) => result.toJson()).toList()},
    );
  }

  Future<void> abandonReviewSession({required String sessionId}) async {
    await _dio.post<void>(
      ApiEndpoints.replaceParams(ApiEndpoints.reviewSessionAbandon, {
        'id': sessionId,
      }),
    );
  }
}
