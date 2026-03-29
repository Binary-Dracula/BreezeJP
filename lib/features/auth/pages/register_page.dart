import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controller/auth_controller.dart';

/// 用户名校验规则
/// - 2~16 字符
/// - 只允许字母、数字、下划线、中文
/// - 不能以下划线开头
final _usernameRegex = RegExp(
  r'^[a-zA-Z0-9\u4e00-\u9fff][a-zA-Z0-9_\u4e00-\u9fff]{1,15}$',
);

/// 注册页
/// 流程：填写用户名 + 邮箱 + 密码 + 确认密码 → 注册 → 自动登录 → /home
///       已有账号 → 返回登录 ← /login
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          _emailController.text,
          _passwordController.text,
          _usernameController.text,
        );
    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 标题 ──
                Text(
                  '创建账号',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '注册后即可使用云端功能',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
                const SizedBox(height: 40),

                // ── 表单 ──
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 用户名（在邮箱上方）
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          hintText: '2‖16 个字符，支持中英文、数字、下划线',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入用户名';
                          if (v.trim().length < 2) return '用户名至少需要 2 个字符';
                          if (v.trim().length > 16) return '用户名最多 16 个字符';
                          if (!_usernameRegex.hasMatch(v.trim())) {
                            return '只允许中英文、数字、下划线，不能以下划线开头';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 邮箱
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '邮箱',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入邮箱';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(v.trim())) {
                            return '邮箱格式不正确';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 密码
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请输入密码';
                          if (v.length < 6) return '密码至少需要 6 位字符';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 确认密码
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleRegister(),
                        decoration: InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请再次输入密码';
                          if (v != _passwordController.text) return '两次密码不一致';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // 错误提示
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            state.error!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // 注册按钮
                      FilledButton(
                        onPressed: state.isLoading ? null : _handleRegister,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('注册', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 返回登录
                TextButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/login'),
                  child: const Text('← 已有账号？返回登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
