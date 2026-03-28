/// 登录/注册页面通用状态
class AuthPageState {
  final bool isLoading;
  final String? error;

  const AuthPageState({this.isLoading = false, this.error});

  AuthPageState copyWith({bool? isLoading, String? error}) {
    return AuthPageState(isLoading: isLoading ?? this.isLoading, error: error);
  }
}
