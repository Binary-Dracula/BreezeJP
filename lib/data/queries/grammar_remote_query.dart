import '../../core/constants/learning_status.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/grammar.dart';
import '../models/grammar_context.dart';
import '../models/grammar_detail.dart';
import '../models/grammar_example.dart';
import '../models/grammar_meaning.dart';

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

  Future<List<GrammarDetail>> fetchGrammarLearningQueue({
    required int limit,
    required List<int> excludeIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.grammarLearningQueue,
      queryParameters: {
        'limit': limit,
        if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds.join(','),
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

    return GrammarDetail(
      grammar: grammar,
      meanings: meanings,
      contexts: contexts,
      examples: examples,
      userState: grammar.userState ?? LearningStatus.unlearned,
    );
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
