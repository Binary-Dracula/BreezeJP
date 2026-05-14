import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'word_remote_command.dart';

final wordRemoteCommandProvider = Provider<WordRemoteCommand>((ref) {
  return WordRemoteCommand();
});
