import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_seed_command.dart';

final debugSeedCommandProvider = Provider<DebugSeedCommand>((ref) {
  return DebugSeedCommand(ref);
});
