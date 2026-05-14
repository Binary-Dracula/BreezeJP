import '../../core/constants/learning_status.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/grammar.dart';
import '../models/grammar_context.dart';
import '../models/grammar_detail.dart';
import '../models/grammar_example.dart';
import '../models/grammar_meaning.dart';
import '../models/study_grammar.dart';

class GrammarRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<GrammarDetail?> fetchGrammarDetail(int grammarId) async {
    final path = ApiEndpoints.replaceParams(ApiEndpoints.grammarDetail, {
      'id': grammarId,
    });
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data?['data'];
    if (data is! Map) {
      return null;
    }
    return _detailFromJson(Map<String, dynamic>.from(data));
  }

  Future<List<GrammarDetail>> fetchGrammars({
    int limit = 20,
    List<int> excludeIds = const [],
    bool unlearnedOnly = false,
    String? jlptLevel,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.grammars,
      queryParameters: {
        'limit': limit,
        if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds.join(','),
        if (unlearnedOnly) 'unlearned_only': true,
        if (jlptLevel != null && jlptLevel.trim().isNotEmpty)
          'jlpt_level': jlptLevel.trim().toUpperCase(),
      },
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => _detailFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  GrammarDetail _detailFromJson(Map<String, dynamic> json) {
    final grammarJson = Map<String, dynamic>.from(json['grammar'] as Map);
    final grammar =
        Grammar.fromMap({
          ...grammarJson,
          'created_at': _isoToSeconds(grammarJson['created_at']),
          'updated_at': _isoToSeconds(grammarJson['updated_at']),
        }).copyWith(
          userState: LearningStatus.fromValue(
            (json['learning_status'] as int?) ?? 0,
          ),
        );

    final meanings = (json['meanings'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              GrammarMeaning.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final contexts = (json['contexts'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              GrammarContext.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final examples = (json['examples'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              GrammarExample.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final learningStateJson = json['learning_state'];
    final learningState = learningStateJson is Map
        ? _learningStateFromJson(
            Map<String, dynamic>.from(learningStateJson),
            grammar.id,
          )
        : null;

    return GrammarDetail(
      grammar: grammar,
      meanings: meanings,
      contexts: contexts,
      examples: examples,
      userState: grammar.userState ?? LearningStatus.unlearned,
      learningState: learningState,
    );
  }

  StudyGrammar _learningStateFromJson(
    Map<String, dynamic> json,
    int grammarId,
  ) {
    return StudyGrammar.fromMap({
      'id': 0,
      'user_id': 0,
      'grammar_id': json['grammar_id'] ?? grammarId,
      'learning_status': (json['learning_status'] as int?) ?? 0,
      'next_review_at': json['next_review_at'],
      'last_reviewed_at': json['last_reviewed_at'],
      'streak': (json['streak'] as int?) ?? 0,
      'total_reviews': (json['total_reviews'] as int?) ?? 0,
      'fail_count': (json['fail_count'] as int?) ?? 0,
      'interval': (json['interval'] as num?)?.toDouble() ?? 0.0,
      'ease_factor': (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      'stability': (json['stability'] as num?)?.toDouble() ?? 0.0,
      'difficulty': (json['difficulty'] as num?)?.toDouble() ?? 0.0,
      'created_at': _isoToSeconds(json['created_at']),
      'updated_at': _isoToSeconds(json['updated_at']),
    });
  }

  int _isoToSeconds(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).millisecondsSinceEpoch ~/ 1000;
    }
    if (value is int) {
      return value;
    }
    return 0;
  }
}
