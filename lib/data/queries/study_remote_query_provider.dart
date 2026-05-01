import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_remote_query.dart';

final studyRemoteQueryProvider = Provider<StudyRemoteQuery>((ref) {
  return StudyRemoteQuery();
});
