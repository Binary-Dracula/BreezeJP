import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/app_state_repository_provider.dart';
import '../repositories/user_repository_provider.dart';
import 'active_user_command.dart';

final activeUserCommandProvider = Provider<ActiveUserCommand>((ref) {
  final appStateRepository = ref.read(appStateRepositoryProvider);
  final userRepository = ref.read(userRepositoryProvider);
  return ActiveUserCommand(appStateRepository, userRepository);
});
