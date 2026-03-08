import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/preferences_provider.dart';
import 'algorithm_service.dart';

/// AlgorithmService Provider
/// 提供全局单例的算法服务
final algorithmServiceProvider = Provider<AlgorithmService>((ref) {
  final service = AlgorithmService();
  final preferredAlgorithm = ref.watch(algorithmTypeProvider);
  service.setPreferredAlgorithm(preferredAlgorithm);
  return service;
});
