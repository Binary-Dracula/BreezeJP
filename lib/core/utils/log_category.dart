/// 日志分类枚举
/// 用于区分不同模块的日志输出
enum LogCategory {
  /// 学习流程日志
  learn('[LEARN]'),

  /// 数据库操作日志
  db('[DB]'),

  /// 音频状态日志
  audio('[AUDIO]'),

  /// 算法计算日志
  algo('[ALGO]');

  const LogCategory(this.prefix);

  /// 日志前缀
  final String prefix;
}
