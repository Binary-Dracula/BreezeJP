/// API 端点常量
/// 集中管理所有 API 路径
class ApiEndpoints {
  // 基础 URL
  static const String baseUrl = 'https://api.binary-dracula.com';

  // 新闻相关 API
  static const String articles = '/api/v1/articles';
  static const String articleDetail = '/api/v1/articles/{id}';
  static const String audio = '/api/v1/audio/{id}';
  static const String health = '/api/v1/health';

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
