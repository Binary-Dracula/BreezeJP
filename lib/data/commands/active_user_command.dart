import '../../core/utils/app_logger.dart';
import '../models/user.dart';
import '../repositories/app_state_repository.dart';
import '../repositories/user_repository.dart';

/// Active user command (write behavior).
class ActiveUserCommand {
  ActiveUserCommand(this._appStateRepository, this._userRepository);

  final AppStateRepository _appStateRepository;
  final UserRepository _userRepository;

  Future<User> ensureActiveUser() async {
    final currentUserId = await _appStateRepository.getCurrentUserId();
    if (currentUserId != null) {
      final user = await _userRepository.getUserById(currentUserId);
      if (user != null) return user;

      logger.warning('app_state 当前用户 $currentUserId 不存在，回退到本地用户列表');
    }

    final users = await _userRepository.getAllUsers();
    if (users.isNotEmpty) {
      final user = users.first;
      await _appStateRepository.setCurrentUserId(user.id);
      return user;
    }

    return createAndActivateDefaultUser();
  }

  Future<User> createAndActivateDefaultUser() async {
    const defaultUsername = 'Breeze 用户';
    final defaultUser = User(
      id: 0,
      username: defaultUsername,
      passwordHash: 'placeholder',
      nickname: defaultUsername,
      locale: 'zh',
      onboardingCompleted: 0,
    );
    final newId = await _userRepository.createUser(defaultUser);
    await _appStateRepository.setCurrentUserId(newId);

    logger.info('创建默认活跃用户: $defaultUsername (#$newId)');

    return defaultUser.copyWith(id: newId);
  }

  Future<void> switchUser(int userId) async {
    final user = await _userRepository.getUserById(userId);
    if (user == null) {
      throw StateError('Active user not found: $userId');
    }

    await _appStateRepository.setCurrentUserId(userId);
  }
}
