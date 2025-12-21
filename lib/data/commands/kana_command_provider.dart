import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kana_command.dart';

final kanaCommandProvider = Provider<KanaCommand>((ref) {
  return KanaCommand(ref);
});
