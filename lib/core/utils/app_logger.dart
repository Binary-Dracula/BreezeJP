import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

import '../algorithm/srs_types.dart';
import '../../data/models/study_log.dart';
import 'log_category.dart';
import 'log_formatter.dart';

const bool _defaultTestMode = bool.fromEnvironment('FLUTTER_TEST');

/// 应用日志工具类
/// 统一管理所有日志输出
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  late Logger _logger;
  late bool _isTestMode;

  AppLogger._internal() {
    _isTestMode = _defaultTestMode;
    _logger = _buildLogger(isTestMode: _isTestMode);
  }

  void setTestMode(bool enabled) {
    if (_isTestMode == enabled) return;
    _isTestMode = enabled;
    _logger = _buildLogger(isTestMode: _isTestMode);
  }

  Logger _buildLogger({required bool isTestMode}) {
    final minLevel = isTestMode ? Level.info : Level.debug;
    return Logger(
      filter: _AppLogFilter(minLevel: minLevel),
      printer: isTestMode
          ? _TestLogPrinter()
          : PrettyPrinter(
              methodCount: 2, // 显示的方法调用栈数量
              errorMethodCount: 8, // 错误时显示的方法调用栈数量
              lineLength: 120, // 每行的宽度
              colors: true, // 彩色输出
              printEmojis: true, // 打印表情符号
              dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // 时间格式
            ),
      output: _AppLogOutput(),
    );
  }

  /// Debug 日志（调试信息）
  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info 日志（一般信息）
  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning 日志（警告信息）
  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error 日志（错误信息）
  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal 日志（致命错误）
  void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Trace 日志（追踪信息）
  void trace(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// 网络请求日志
  void network(String method, String url, {Map<String, dynamic>? data}) {
    info('🌐 [$method] $url${data != null ? '\nData: $data' : ''}');
  }

  /// 网络响应日志
  void networkResponse(int statusCode, String url, {dynamic data}) {
    info('✅ [$statusCode] $url${data != null ? '\nResponse: $data' : ''}');
  }

  /// 网络错误日志
  void networkError(String method, String url, dynamic error) {
    this.error('❌ [$method] $url\nError: $error');
  }

  /// 数据库日志 (旧方法，保留兼容性)
  void database(String operation, {String? table, dynamic data}) {
    debug(
      '💾 DB[$operation]${table != null ? ' $table' : ''}${data != null ? '\nData: $data' : ''}',
    );
  }

  // ==================== 学习流程日志 [LEARN] ====================

  /// 记录学习会话开始
  /// Requirements: 1.2, 2.1
  void learnSessionStart({required int userId}) {
    final timestamp = LogFormatter.formatTimestamp(DateTime.now());
    info(
      '${LogCategory.learn.prefix} session_start: userId=$userId, timestamp=$timestamp',
    );
  }

  /// 记录单词加载
  /// Requirements: 1.2, 2.2
  void learnWordsLoaded({
    required int reviewCount,
    required int newCount,
    required int totalCount,
  }) {
    info(
      '${LogCategory.learn.prefix} words_loaded: review=$reviewCount, new=$newCount, total=$totalCount',
    );
  }

  /// 记录单词查看
  /// Requirements: 1.2, 2.3
  void learnWordView({
    required int wordId,
    required int position,
    required int total,
  }) {
    info(
      '${LogCategory.learn.prefix} word_view: wordId=$wordId, position=$position/$total',
    );
  }

  /// 记录答案提交
  /// Requirements: 1.2, 2.4
  void learnAnswerSubmit({
    required int wordId,
    required String rating,
    required double newInterval,
    required double newEaseFactor,
  }) {
    info(
      '${LogCategory.learn.prefix} answer_submit: wordId=$wordId, rating=$rating, interval=${newInterval.toStringAsFixed(2)}, ef=${newEaseFactor.toStringAsFixed(3)}',
    );
  }

  /// 记录学习会话结束
  /// Requirements: 1.2, 2.5
  void learnSessionEnd({
    required int durationMs,
    required int learnedCount,
    required int reviewedCount,
  }) {
    final duration = LogFormatter.formatDuration(durationMs);
    info(
      '${LogCategory.learn.prefix} session_end: duration=$duration, learned=$learnedCount, reviewed=$reviewedCount',
    );
  }

  /// 记录学习状态迁移
  void stateChange({
    required String scope,
    required int userId,
    required int itemId,
    required String fromState,
    required String toState,
    String? reason,
  }) {
    final reasonPart = reason != null ? ', reason=$reason' : '';
    info(
      '${LogCategory.learn.prefix} state_change: scope=$scope, userId=$userId, itemId=$itemId, from=$fromState, to=$toState$reasonPart',
    );
  }

  // ==================== 数据库操作日志 [DB] ====================

  /// 记录数据库查询
  /// Requirements: 1.3, 3.1
  void dbQuery({required String table, String? where, int? resultCount}) {
    final parts = <String>['table=$table'];
    if (where != null) parts.add('where="$where"');
    if (resultCount != null) parts.add('results=$resultCount');
    debug('${LogCategory.db.prefix} query: ${parts.join(', ')}');
  }

  /// 记录数据库插入
  /// Requirements: 1.3, 3.2
  void dbInsert({
    required String table,
    required int id,
    Map<String, dynamic>? keyFields,
  }) {
    final parts = <String>['table=$table', 'id=$id'];
    if (keyFields != null && keyFields.isNotEmpty) {
      parts.add(LogFormatter.formatKeyValues(keyFields));
    }
    debug('${LogCategory.db.prefix} insert: ${parts.join(', ')}');
  }

  /// 记录数据库更新
  /// Requirements: 1.3, 3.3
  void dbUpdate({
    required String table,
    required int affectedRows,
    List<String>? updatedFields,
  }) {
    final parts = <String>['table=$table', 'affected=$affectedRows'];
    if (updatedFields != null && updatedFields.isNotEmpty) {
      parts.add('fields=[${updatedFields.join(', ')}]');
    }
    debug('${LogCategory.db.prefix} update: ${parts.join(', ')}');
  }

  /// 记录数据库删除
  /// Requirements: 1.3, 3.4
  void dbDelete({required String table, required int deletedRows}) {
    debug(
      '${LogCategory.db.prefix} delete: table=$table, deleted=$deletedRows',
    );
  }

  /// 记录数据库错误
  /// Requirements: 1.3, 3.5
  void dbError({
    required String operation,
    required String table,
    required dynamic dbError,
    StackTrace? stackTrace,
  }) {
    error(
      '${LogCategory.db.prefix} error: op=$operation, table=$table, error="$dbError"',
      dbError,
      stackTrace,
    );
  }

  // ==================== 音频状态日志 [AUDIO] ====================

  /// 记录音频播放开始
  /// Requirements: 1.4, 4.1
  void audioPlayStart({required String source}) {
    info('${LogCategory.audio.prefix} play_start: $source');
  }

  /// 记录音频播放完成
  /// Requirements: 1.4, 4.2
  void audioPlayComplete({required String source}) {
    info('${LogCategory.audio.prefix} play_complete: source="$source"');
  }

  /// 记录音频播放失败
  /// Requirements: 1.4, 4.3
  void audioPlayError({
    required String audio,
    required String errorType,
    required String errorMessage,
  }) {
    error(
      '${LogCategory.audio.prefix} play_error: source="$audio", type=$errorType, msg="$errorMessage"',
    );
  }

  /// 记录音频状态变化
  /// Requirements: 1.4, 4.4
  void audioStateChange({required String newState}) {
    info('${LogCategory.audio.prefix} state_change: $newState');
  }

  // ==================== 算法状态日志 [ALGO] ====================

  /// 记录 SRS 计算开始
  /// Requirements: 1.5, 5.1
  void algoCalculateStart({
    required String algorithmType,
    required SRSInput input,
  }) {
    final inputStr = LogFormatter.formatSRSInput(input);
    final message =
        '${LogCategory.algo.prefix} calculate_start: type=$algorithmType, $inputStr';
    if (_isTestMode) {
      debug(message);
    } else {
      info(message);
    }
  }

  /// 记录 SRS 计算完成
  /// Requirements: 1.5, 5.2
  void algoCalculateComplete({
    required String algorithmType,
    required SRSOutput output,
  }) {
    final outputStr = LogFormatter.formatSRSOutput(output);
    final message =
        '${LogCategory.algo.prefix} calculate_complete: type=$algorithmType, $outputStr';
    if (_isTestMode) {
      debug(message);
    } else {
      info(message);
    }
  }

  /// 记录参数更新
  /// Requirements: 1.5, 5.3
  void algoParamsUpdate({
    required int wordId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    final changes = <String>[];
    for (final key in after.keys) {
      final beforeVal = before[key];
      final afterVal = after[key];
      if (beforeVal != afterVal) {
        changes.add('$key: $beforeVal -> $afterVal');
      }
    }
    info(
      '${LogCategory.algo.prefix} params_update: wordId=$wordId, ${changes.join(', ')}',
    );
  }

  /// 记录复习计划变更
  /// Requirements: 1.5, 5.4
  void algoScheduleChange({
    required int wordId,
    required DateTime? oldSchedule,
    required DateTime newSchedule,
  }) {
    final oldStr = oldSchedule != null
        ? LogFormatter.formatTimestamp(oldSchedule)
        : 'null';
    final newStr = LogFormatter.formatTimestamp(newSchedule);
    info(
      '${LogCategory.algo.prefix} schedule_change: wordId=$wordId, old=$oldStr, new=$newStr',
    );
  }

  /// 记录 SRS 状态更新（对比前后差异）
  void srsUpdate({
    required String scope,
    required int userId,
    required int itemId,
    required ReviewRating rating,
    required AlgorithmType algorithmType,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    final changes = LogFormatter.formatChanges(before, after);
    info(
      '${LogCategory.algo.prefix} srs_update: scope=$scope, userId=$userId, itemId=$itemId, rating=${rating.name}, algo=${algorithmType.name}, $changes',
    );
  }
}

/// 日志过滤器 - 仅在 Debug 模式输出日志
class _AppLogFilter extends LogFilter {
  _AppLogFilter({required this.minLevel});

  final Level minLevel;

  @override
  bool shouldLog(LogEvent event) {
    // 仅在 Debug 模式输出日志
    return kDebugMode && event.level.index >= minLevel.index;
  }
}

/// 日志输出器 - 自定义输出行为
class _AppLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // 在 Debug 模式下输出到控制台
    if (kDebugMode) {
      for (var line in event.lines) {
        // ignore: avoid_print
        print(line);
      }
    }

    // 可以在这里添加其他输出方式，例如：
    // - 写入文件
    // - 发送到远程日志服务器
    // - 保存到数据库
  }
}

class _TestLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final level = event.level.name.toUpperCase();
    final message = event.message?.toString() ?? '';
    final buffer = StringBuffer('[$level] $message');
    if (event.error != null) {
      buffer.write(' error=${event.error}');
    }
    if (event.stackTrace != null && event.level.index >= Level.error.index) {
      final firstLine = event.stackTrace
          .toString()
          .split('\n')
          .first
          .trim();
      if (firstLine.isNotEmpty) {
        buffer.write(' stack=$firstLine');
      }
    }
    return [buffer.toString()];
  }
}

/// 全局日志实例
final logger = AppLogger();
