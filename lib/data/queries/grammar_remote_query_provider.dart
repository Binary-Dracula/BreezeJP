import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grammar_remote_query.dart';

final grammarRemoteQueryProvider = Provider<GrammarRemoteQuery>((ref) {
  return GrammarRemoteQuery();
});
