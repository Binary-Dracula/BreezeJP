import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kana_remote_query.dart';

final kanaRemoteQueryProvider = Provider<KanaRemoteQuery>((ref) {
  return KanaRemoteQuery();
});
