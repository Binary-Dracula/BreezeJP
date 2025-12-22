import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_kana_command.dart';

final debugKanaCommandProvider = Provider<DebugKanaCommand>((ref) {
  return DebugKanaCommand(ref);
});
