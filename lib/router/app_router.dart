import 'package:go_router/go_router.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/home/pages/home_page.dart';

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash 页面
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),

    // 主页面
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // TODO: 添加其他路由
    // 学习页面、复习页面、设置页面等
  ],
);
