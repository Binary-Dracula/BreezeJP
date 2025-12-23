import '../models/app_state.dart';
import '../models/user.dart';
import '../repositories/app_state_repository.dart';
import '../repositories/user_repository.dart';

/// Active user query (read-only).
class ActiveUserQuery {
  ActiveUserQuery(this._appStateRepository, this._userRepository);

  final AppStateRepository _appStateRepository;
  final UserRepository _userRepository;

  Future<int?> getActiveUserId() async {
    final state = await _appStateRepository.getState(AppState.singletonId);
    return state?.currentUserId;
  }

  Future<User?> getActiveUser() async {
    final userId = await getActiveUserId();
    if (userId == null) return null;
    return _userRepository.getUserById(userId);
  }
}
