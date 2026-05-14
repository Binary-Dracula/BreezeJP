import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kana_remote_command.dart';

final kanaRemoteCommandProvider = Provider<KanaRemoteCommand>((ref) {
  return KanaRemoteCommand();
});
