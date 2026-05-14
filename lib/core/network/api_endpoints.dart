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
  static const String learnSessions = '/api/v1/learn/sessions';
  static const String learnSessionComplete =
      '/api/v1/learn/sessions/{id}/complete';
  static const String wordDetail = '/api/v1/words/{id}';
  static const String reviewSessions = '/api/v1/review/sessions';
  static const String reviewSessionComplete =
      '/api/v1/review/sessions/{id}/complete';
  static const String reviewSessionAbandon =
      '/api/v1/review/sessions/{id}/abandon';
  static const String wordBook = '/api/v1/me/word-book';
  static const String exampleFavorites = '/api/v1/me/example-favorites';
  static const String wordFavoritesToggle = '/api/v1/favorites/words/toggle';
  static const String exampleFavoritesToggle =
      '/api/v1/favorites/examples/toggle';
  static const String grammarBook = '/api/v1/me/grammar-book';
  static const String homeSummary = '/api/v1/me/home-summary';
  static const String grammarDetail = '/api/v1/grammars/{id}';
  static const String grammars = '/api/v1/grammars';
  static const String grammarStates = '/api/v1/grammar/states';
  static const String wordStates = '/api/v1/word/states';
  static const String kanaStates = '/api/v1/kana/states';
  static const String meKanaStates = '/api/v1/me/kana-states';
  static const String reference = '/api/v1/reference';

  // 问题上报
  static const String issues = '/api/v1/issues';

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
