/// Splash 页面状态
class SplashState {
  final bool isLoading;
  final String message;
  final String? error;
  final bool isInitialized;

  const SplashState({
    this.isLoading = true,
    this.message = '正在初始化...',
    this.error,
    this.isInitialized = false,
  });

  SplashState copyWith({
    bool? isLoading,
    String? message,
    String? error,
    bool? isInitialized,
  }) {
    return SplashState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}
