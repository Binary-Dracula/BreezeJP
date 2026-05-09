import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/home_summary_invalidation_provider.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/sync_remote_command.dart';
import '../../../data/commands/sync_scheduler_command_provider.dart';
import '../state/auth_page_state.dart';
import '../../home/controller/home_controller.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthPageState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthPageState> {
  @override
  AuthPageState build() => const AuthPageState();

  AuthService get _auth => ref.read(authServiceProvider);

  /// 邮箱密码登录，成功返回 true
  Future<bool> signIn(String email, String password) async {
    state = const AuthPageState(isLoading: true);
    try {
      final response = await _auth.signInWithEmail(email, password);
      if (response.session != null) {
        await _prepareAuthenticatedHome();
        state = const AuthPageState();
        return true;
      }
      state = const AuthPageState(error: '登录失败，请重试');
      return false;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 邮箱密码注册，成功返回 true（MVP 跳过邮件确认，注册即登录）
  Future<bool> signUp(String email, String password, String displayName) async {
    state = const AuthPageState(isLoading: true);
    try {
      final response = await _auth.signUpWithEmail(
        email,
        password,
        displayName,
      );

      // 邮件确认已关闭时，signUp 直接返回 session
      if (response.session != null) {
        await _prepareAuthenticatedHome();
        state = const AuthPageState();
        return true;
      }

      // Supabase 创建了 user 但未返回 session（后台"Confirm email"仍开启）
      // 尝试自动 signIn
      if (response.user != null) {
        return await signIn(email, password);
      }

      state = const AuthPageState(error: '注册失败，请重试');
      return false;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 修改用户名（display_name）
  Future<bool> updateDisplayName(String displayName) async {
    state = const AuthPageState(isLoading: true);
    try {
      await _auth.updateDisplayName(displayName);
      final activeUser = await ref
          .read(activeUserCommandProvider)
          .ensureActiveUser();
      await ref
          .read(syncRemoteCommandProvider)
          .checkpointForCurrentUser(localUserId: activeUser.id);
      ref.read(homeSummaryInvalidationProvider.notifier).markStale();
      state = const AuthPageState();
      return true;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 修改密码
  Future<bool> updatePassword(String newPassword) async {
    state = const AuthPageState(isLoading: true);
    try {
      await _auth.updatePassword(newPassword);
      state = const AuthPageState();
      return true;
    } catch (e) {
      state = AuthPageState(error: _friendlyError(e.toString()));
      return false;
    }
  }

  /// 退出登录
  Future<void> signOut() async {
    state = const AuthPageState(isLoading: true);
    try {
      ref.read(syncSchedulerCommandProvider).stop();
      await _auth.signOut();
    } finally {
      state = const AuthPageState();
    }
  }

  /// 登录/注册后的准备流程：同步完成 + Home 数据预加载，完成后再返回（导航发生前）
  Future<void> _prepareAuthenticatedHome() async {
    final activeUser = await ref
        .read(activeUserCommandProvider)
        .ensureActiveUser();

    // 1. 同步云端数据（阻塞：完成后才跳转 Home）
    try {
      await ref
          .read(syncRemoteCommandProvider)
          .checkpointForCurrentUser(localUserId: activeUser.id);
    } catch (e) {
      logger.warning('[Auth] 登录后首轮云端同步失败，稍后重试: $e');
    }

    // 2. 预加载 Home 摘要（让 Home 页面一进来就有数据）
    try {
      await ref.read(homeControllerProvider.notifier).loadHomeData();
    } catch (e) {
      logger.warning('[Auth] Home 数据预加载失败: $e');
    }

    // 3. 启动定期同步调度器
    await ref.read(syncSchedulerCommandProvider).start();
  }

  /// 将 Supabase 错误信息转为用户友好文案
  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) return '邮箱或密码错误';
    if (raw.contains('Email not confirmed')) return '请先确认注册邮件';
    if (raw.contains('User already registered')) return '该邮箱已注册，请直接登录';
    if (raw.contains('Password should be at least')) return '密码至少需要 6 位字符';
    if (raw.contains('Unable to validate email')) return '邮箱格式不正确';
    if (raw.contains('network')) return '网络连接失败，请检查网络';
    if (raw.contains('same password')) return '新密码不能与当前密码相同';
    return '操作失败，请稍后重试';
  }
}
