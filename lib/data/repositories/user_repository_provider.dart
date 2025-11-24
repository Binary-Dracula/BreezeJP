import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_repository.dart';

/// UserRepository Provider
/// 提供全局单例的用户数据仓库
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
