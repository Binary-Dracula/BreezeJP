import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../features/review/shared/review_session_codec.dart';
import '../../features/word_review/state/word_review_state.dart';

final reviewSessionRemoteCommandProvider = Provider<ReviewSessionRemoteCommand>(
  (ref) {
    return ReviewSessionRemoteCommand();
  },
);

class ReviewSessionRemoteCommand {
  final _dio = DioClient.instance.dio;

  Future<void> saveWordSession({
    required String sessionId,
    required WordReviewState state,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.wordReviewSession,
      data: encodeWordReviewSessionUpdate(
        sessionId: sessionId,
        state: state,
        isFinished: false,
      ),
    );
  }

  Future<void> completeWordSession({
    required String sessionId,
    required WordReviewState state,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.wordReviewSession,
      data: encodeWordReviewSessionUpdate(
        sessionId: sessionId,
        state: state,
        isFinished: true,
      ),
    );
  }
}
