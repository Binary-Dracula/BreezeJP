import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../auth/controller/auth_controller.dart';

/// 个人资料页
/// 展示：头像缩写、用户名（可编辑）、邮箱（只读）
/// 操作：修改密码 → /change-password，退出登录 → /login
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final currentUser = ref.watch(currentUserProvider);
    final email = currentUser?.email ?? '';
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final initials = (displayName?.isNotEmpty == true)
        ? displayName![0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('个人资料'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头像
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 信息卡片
              _Card(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: '用户名',
                    value: displayName ?? '（未设置）',
                    onTap: () =>
                        _showEditUsernameDialog(context, ref, displayName),
                  ),
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: '邮箱',
                    value: email,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 操作卡片
              _Card(
                children: [
                  _ActionRow(
                    icon: Icons.lock_outline,
                    label: '修改密码',
                    onTap: () => context.push('change-password'),
                  ),
                ],
              ),

              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  authState.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),

              // 退出登录
              FilledButton(
                onPressed: authState.isLoading
                    ? null
                    : () => _handleSignOut(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('退出登录', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _showEditUsernameDialog(
    BuildContext context,
    WidgetRef ref,
    String? currentName,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditUsernameDialog(currentName: currentName),
    );

    if (result == null || result == currentName) return;

    if (context.mounted) {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .updateDisplayName(result);
      if (ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用户名已更新')));
      }
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
      trailing: onTap != null
          ? const Icon(Icons.edit_outlined, size: 18, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}

/// 编辑用户名 dialog widget
/// 独立的 StatefulWidget 以正确管理 TextEditingController 的生命周期
class _EditUsernameDialog extends StatefulWidget {
  const _EditUsernameDialog({required this.currentName});
  final String? currentName;

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  final _usernameRegex = RegExp(
    r'^[a-zA-Z0-9\u4e00-\u9fff][a-zA-Z0-9_\u4e00-\u9fff]{1,15}$',
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改用户名'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '2~16 个字符',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '请输入用户名';
            if (v.trim().length < 2) return '至少 2 个字符';
            if (v.trim().length > 16) return '最多 16 个字符';
            if (!_usernameRegex.hasMatch(v.trim())) {
              return '只允许中英文、数字、下划线，不能以下划线开头';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
