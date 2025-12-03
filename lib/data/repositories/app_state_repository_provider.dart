import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state_repository.dart';

/// AppStateRepository Provider
/// 提供全局单例的应用状态仓库
final appStateRepositoryProvider = Provider<AppStateRepository>((ref) {
  return AppStateRepository();
});
