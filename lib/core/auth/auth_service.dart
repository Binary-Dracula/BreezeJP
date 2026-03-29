import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth 薄封装
/// 只暴露 App 实际需要的操作，隔离第三方 SDK 依赖
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 当前 Session（null = 游客）
  Session? get currentSession => _client.auth.currentSession;

  /// 当前用户（null = 游客）
  User? get currentUser => _client.auth.currentUser;

  /// 当前用户的 display_name（用户名），存於 user_metadata
  String? get displayName =>
      _client.auth.currentUser?.userMetadata?['display_name'] as String?;

  /// 当前用户的邮箱
  String? get email => _client.auth.currentUser?.email;

  /// 认证状态变化流（登录/登出事件）
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// 邮箱密码登录
  Future<AuthResponse> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// 邮箱密码注册（MVP 跳过邮件确认，Supabase 后台已关闭验证）
  /// [displayName] 存入 user_metadata.display_name
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  /// 修改 display_name（用户名）
  Future<UserResponse> updateDisplayName(String displayName) {
    return _client.auth.updateUser(
      UserAttributes(data: {'display_name': displayName.trim()}),
    );
  }

  /// 修改密码（当前 session 下直接生效，无需旧密码）
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// 退出登录
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
