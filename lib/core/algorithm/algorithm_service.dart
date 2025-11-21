import 'srs_types.dart';
import 'sm2_algorithm.dart';
import 'fsrs_algorithm.dart';

/// 算法服务
/// 负责管理和调度不同的 SRS 算法
class AlgorithmService {
  // 单例模式
  static final AlgorithmService _instance = AlgorithmService._internal();
  factory AlgorithmService() => _instance;
  AlgorithmService._internal();

  final _sm2 = SM2Algorithm();
  final _fsrs = FSRSAlgorithm();

  /// 计算下一次复习状态
  /// [algorithmType] 指定使用的算法类型
  /// [input] 当前状态输入
  SRSOutput calculate({
    required AlgorithmType algorithmType,
    required SRSInput input,
  }) {
    switch (algorithmType) {
      case AlgorithmType.sm2:
        return _sm2.calculate(input);
      case AlgorithmType.fsrs:
        return _fsrs.calculate(input);
    }
  }

  /// 获取默认算法 (免费版默认 SM-2)
  AlgorithmType get defaultAlgorithm => AlgorithmType.sm2;

  /// 检查是否支持该算法 (预留给付费逻辑)
  bool isAlgorithmSupported(AlgorithmType type, {bool isPremium = false}) {
    if (type == AlgorithmType.sm2) return true;
    if (type == AlgorithmType.fsrs) return isPremium;
    return false;
  }

  /// 辅助方法：从整数获取算法类型
  static AlgorithmType getAlgorithmType(int value) {
    if (value == 2) return AlgorithmType.fsrs;
    return AlgorithmType.sm2;
  }

  /// 辅助方法：获取算法类型的整数值
  static int getAlgorithmValue(AlgorithmType type) {
    return type == AlgorithmType.fsrs ? 2 : 1;
  }
}
