import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_session_command.dart';

final studySessionCommandProvider = Provider<StudySessionCommand>((ref) {
  return StudySessionCommand(ref);
});
