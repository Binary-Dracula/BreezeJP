/// API 端点常量
/// 集中管理所有 API 路径
class ApiEndpoints {
  // 基础 URL
  static const String baseUrl = 'https://api.binary-dracula.com';

  // 新闻相关 API
  static const String articles = '/api/v1/articles';
  static const String articleDetail = '/api/v1/articles/{id}';
  static const String audio = '/api/v1/audio/{id}';
  static const String wordAudio = '/api/v1/audio/words/{id}';
  static const String health = '/api/v1/health';

  // 词汇相关 API
  static const String books = '/api/v1/books';
  static const String bookSync = '/api/v1/books/sync';
  static const String bookNextWords = '/api/v1/books/{bookId}/next-words';
  static const String learnNextWords = '/api/v1/learn/books/{bookId}/next';
  static const String wordDetail = '/api/v1/words/{id}';
  static const String wordSync = '/api/v1/words/sync';
  static const String wordReviewSession = '/api/v1/review/words/session';
  static const String wordBook = '/api/v1/me/word-book';
  static const String exampleFavorites = '/api/v1/me/example-favorites';
  static const String grammarBook = '/api/v1/me/grammar-book';
  static const String homeSummary = '/api/v1/me/home-summary';
  static const String grammarDetail = '/api/v1/grammars/{id}';
  static const String grammarLearningQueue = '/api/v1/grammar-learning/queue';
  static const String reference = '/api/v1/reference';

  // 问题上报
  static const String issues = '/api/v1/issues';

  // 用户数据同步
  static const String syncRegisterDevice = '/api/v1/sync/register-device';
  static const String syncBootstrap = '/api/v1/sync/bootstrap';
  static const String syncPull = '/api/v1/sync/pull';
  static const String syncPush = '/api/v1/sync/push';

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
