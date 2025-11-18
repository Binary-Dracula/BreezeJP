import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/splash_controller.dart';

/// Splash 页面 - 应用启动时的加载页面
/// 负责初始化数据库等预处理工作
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    // 启动初始化流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(splashControllerProvider.notifier).initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(splashControllerProvider);

    // 监听初始化完成状态，自动跳转
    ref.listen(splashControllerProvider, (previous, next) {
      if (next.isInitialized) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5), // 蓝色主题
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo 或应用名称
            Text(
              l10n.appName,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appSubtitle,
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 48),

            // 加载指示器
            if (state.isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                state.message,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],

            // 错误信息
            if (state.error != null) ...[
              const Icon(Icons.error_outline, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(splashControllerProvider.notifier)
                      .initialize(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E88E5),
                ),
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
