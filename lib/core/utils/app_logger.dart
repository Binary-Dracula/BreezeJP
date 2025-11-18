import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// 应用日志工具类
/// 统一管理所有日志输出
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  late final Logger _logger;

  AppLogger._internal() {
    _logger = Logger(
      filter: _AppLogFilter(),
      printer: PrettyPrinter(
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

  /// 数据库日志
  void database(String operation, {String? table, dynamic data}) {
    debug(
      '💾 DB[$operation]${table != null ? ' $table' : ''}${data != null ? '\nData: $data' : ''}',
    );
  }
}

/// 日志过滤器 - 仅在 Debug 模式输出日志
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // 仅在 Debug 模式输出日志
    return kDebugMode;
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

/// 全局日志实例
final logger = AppLogger();
