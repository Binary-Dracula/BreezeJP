import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 问题上报命令
/// 将用户反馈的单词/语法问题提交到服务端
class IssueReportCommand {
  final _dio = DioClient.instance;

  /// 提交问题上报
  ///
  /// [contentType] - 'word' 或 'grammar'
  /// [contentId] - word UUID 或 grammar int id
  /// [contentSnapshot] - 当前数据快照
  /// [message] - 用户描述（可为空）
  Future<void> reportIssue({
    required String contentType,
    required String contentId,
    required Map<String, dynamic> contentSnapshot,
    String? message,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const IssueReportAuthRequiredException();
    }

    logger.info('[IssueReport] 提交上报: type=$contentType, id=$contentId');

    await _dio.post(
      ApiEndpoints.issues,
      data: {
        'content_type': contentType,
        'content_id': contentId,
        'content_snapshot': contentSnapshot,
        'message': message,
      },
    );

    logger.info('[IssueReport] 上报成功');
  }
}

class IssueReportAuthRequiredException implements Exception {
  const IssueReportAuthRequiredException();
}
