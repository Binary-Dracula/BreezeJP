import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../models/user.dart';
import 'app_state_repository_provider.dart';
import 'user_repository_provider.dart';

/// 当前活跃用户 Provider
/// 负责从 app_state 表读取或创建活跃用户
final activeUserProvider = FutureProvider<User>((ref) async {
  final appStateRepository = ref.read(appStateRepositoryProvider);
  final userRepository = ref.read(userRepositoryProvider);

  // 1) 优先使用 app_state 中记录的用户
  final currentUserId = await appStateRepository.getCurrentUserId();
  if (currentUserId != null) {
    final user = await userRepository.getUserById(currentUserId);
    if (user != null) return user;

    logger.warning('app_state 当前用户 $currentUserId 不存在，回退到本地用户列表');
  }

  // 2) 其次使用已有用户
  final users = await userRepository.getAllUsers();
  if (users.isNotEmpty) {
    final user = users.first;
    await appStateRepository.setCurrentUserId(user.id);
    return user;
  }

  // 3) 没有用户时创建一个默认用户
  const defaultUsername = 'Breeze 用户';
  final defaultUser = User(
    id: 0,
    username: defaultUsername,
    passwordHash: 'placeholder',
    nickname: defaultUsername,
    locale: 'zh',
    onboardingCompleted: 0,
  );
  final newId = await userRepository.createUser(defaultUser);
  await appStateRepository.setCurrentUserId(newId);

  logger.info('创建默认活跃用户: $defaultUsername (#$newId)');

  return defaultUser.copyWith(id: newId);
});
