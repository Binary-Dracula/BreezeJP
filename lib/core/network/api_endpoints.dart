/// API 端点常量
/// 集中管理所有 API 路径
class ApiEndpoints {
  // 基础 URL（根据实际情况修改）
  static const String baseUrl = 'https://api.example.com';

  // 示例：单词相关 API
  static const String words = '/words';
  static const String wordDetail = '/words/{id}';
  static const String wordsByLevel = '/words/level/{level}';

  // 示例：用户相关 API
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/user/profile';

  // 示例：学习记录 API
  static const String learningProgress = '/learning/progress';
  static const String reviewRecords = '/learning/reviews';

  // 示例：音频下载 API
  static const String audioDownload = '/audio/{filename}';

  /// 替换路径参数
  /// 例如: replaceParams('/words/{id}', {'id': '123'}) => '/words/123'
  static String replaceParams(String path, Map<String, dynamic> params) {
    var result = path;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}
