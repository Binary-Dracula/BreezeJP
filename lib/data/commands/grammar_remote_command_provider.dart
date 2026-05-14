import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grammar_remote_command.dart';

final grammarRemoteCommandProvider = Provider<GrammarRemoteCommand>((ref) {
  return GrammarRemoteCommand();
});
