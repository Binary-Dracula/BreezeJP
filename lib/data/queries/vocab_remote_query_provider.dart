import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vocab_remote_query.dart';

final vocabRemoteQueryProvider = Provider<VocabRemoteQuery>((ref) {
  return VocabRemoteQuery();
});
