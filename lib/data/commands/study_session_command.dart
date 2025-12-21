import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session/study_session_context.dart';
import 'session/study_session_handle.dart';

/// Study session command (flow orchestration).
class StudySessionCommand {
  StudySessionCommand(this.ref);

  final Ref ref;

  StudySessionHandle createSession(int userId) {
    return StudySessionHandle(
      ref,
      StudySessionContext(userId: userId),
    );
  }
}
