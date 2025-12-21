import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap_command.dart';

final appBootstrapCommandProvider = Provider<AppBootstrapCommand>((ref) {
  return AppBootstrapCommand(ref);
});
