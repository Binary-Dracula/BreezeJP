import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reference_remote_query.dart';

final referenceRemoteQueryProvider = Provider<ReferenceRemoteQuery>((ref) {
  return ReferenceRemoteQuery();
});
