/// Splash 页面状态
class SplashState {
  final bool isLoading;
  final String message;
  final String? error;
  final bool isInitialized;
  // true = 有已登录的 Session，跳转 /home；false = 无 Session，跳转 /login
  final bool hasSession;

  const SplashState({
    this.isLoading = true,
    this.message = '正在初始化...',
    this.error,
    this.isInitialized = false,
    this.hasSession = false,
  });

  SplashState copyWith({
    bool? isLoading,
    String? message,
    String? error,
    bool? isInitialized,
    bool? hasSession,
  }) {
    return SplashState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      hasSession: hasSession ?? this.hasSession,
    );
  }
}
