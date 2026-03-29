import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// AuthService 单例 Provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// 认证状态变化流（全局监听登录/登出事件）
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

/// 当前用户（null = 游客模式）
/// 通过监听 authStateChangesProvider 使自身在登录/登出时自动重建
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider); // 订阅 auth 流，状态变化时触发重建
  return ref.read(authServiceProvider).currentUser;
});

/// 是否已登录（便捷 bool）
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
