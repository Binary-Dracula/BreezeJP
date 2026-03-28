import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../state/auth_page_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthPageState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthPageState> {
  @override
  AuthPageState build() => const AuthPageState();

  AuthService get _auth => ref.read(authServiceProvider);

  /// 邮箱密码登录，成功返回 true，失败返回 false 并在 state.error 中保存错误信息
  Future<bool> signIn(String email, String password) async {
    state = const AuthPageState(isLoading: true);
    try {
      final response = await _auth.signInWithEmail(email, password);
      if (response.session != null) {
        state = const AuthPageState();
        return true;
      }
      state = AuthPageState(error: '登录失败，请重试');
      return false;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 邮箱密码注册，成功返回 true（MVP 跳过邮件确认，注册即登录）
  Future<bool> signUp(String email, String password) async {
    state = const AuthPageState(isLoading: true);
    try {
      final response = await _auth.signUpWithEmail(email, password);

      // 邮件确认已关闭时，signUp 直接返回 session
      if (response.session != null) {
        state = const AuthPageState();
        return true;
      }

      // Supabase 创建了 user 但未返回 session（后台"Confirm email"仍开启）
      // 尝试自动 signIn，关闭邮件确认后此路径同样可正常登录
      if (response.user != null) {
        return await signIn(email, password);
      }

      state = AuthPageState(error: '注册失败，请重试');
      return false;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 将 Supabase 错误信息转为用户友好文案
  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) return '邮箱或密码错误';
    if (raw.contains('Email not confirmed')) return '请先确认注册邮件';
    if (raw.contains('User already registered')) return '该邮箱已注册，请直接登录';
    if (raw.contains('Password should be at least')) return '密码至少需要 6 位字符';
    if (raw.contains('Unable to validate email')) return '邮箱格式不正确';
    if (raw.contains('network')) return '网络连接失败，请检查网络';
    return '操作失败，请稍后重试';
  }
}
