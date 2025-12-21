import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session/session_scope.dart';
import 'session/study_session_handle.dart';

/// Study session command (flow orchestration).
class StudySessionCommand {
  StudySessionCommand(this.ref);

  final Ref ref;

  StudySessionHandle createSession({
    required int userId,
    required SessionScope scope,
  }) {
    return StudySessionHandle(
      userId: userId,
      scope: scope,
      ref: ref,
    );
  }
}
