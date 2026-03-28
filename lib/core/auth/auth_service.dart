import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth 薄封装
/// 只暴露 App 实际需要的操作，隔离第三方 SDK 依赖
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 当前 Session（null = 游客）
  Session? get currentSession => _client.auth.currentSession;

  /// 当前用户（null = 游客）
  User? get currentUser => _client.auth.currentUser;

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
  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return _client.auth.signUp(email: email.trim(), password: password);
  }

  /// 退出登录
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
