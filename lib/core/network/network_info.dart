// 注意：使用此文件需要添加依赖：connectivity_plus: ^6.1.2
// 如果不需要网络状态检查功能，可以删除此文件

// import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络状态检查工具
///
/// 使用前需要在 pubspec.yaml 中添加依赖：
/// ```yaml
/// dependencies:
///   connectivity_plus: ^6.1.2
/// ```
///
/// 然后取消下面代码的注释
class NetworkInfo {
  // final Connectivity _connectivity = Connectivity();

  /// 检查是否有网络连接
  Future<bool> get isConnected async {
    // final result = await _connectivity.checkConnectivity();
    // return result.contains(ConnectivityResult.mobile) ||
    //     result.contains(ConnectivityResult.wifi) ||
    //     result.contains(ConnectivityResult.ethernet);

    // 临时实现：假设总是有网络
    return true;
  }

  /// 获取当前连接类型
  // Future<ConnectivityResult> get connectionType async {
  //   final results = await _connectivity.checkConnectivity();
  //   if (results.isEmpty) {
  //     return ConnectivityResult.none;
  //   }
  //   return results.first;
  // }

  /// 监听网络状态变化
  // Stream<List<ConnectivityResult>> get onConnectivityChanged {
  //   return _connectivity.onConnectivityChanged;
  // }
}
