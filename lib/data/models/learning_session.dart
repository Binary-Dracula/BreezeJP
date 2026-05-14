import 'dart:convert';
import 'package:uuid/uuid.dart';

enum LearningSessionType {
  wordLearn('word_learn'),
  wordReview('word_review'),
  kanaReview('kana_review');

  const LearningSessionType(this.dbValue);

  final String dbValue;

  static LearningSessionType fromDbValue(String value) {
    return LearningSessionType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw ArgumentError('Unknown session type: $value'),
    );
  }
}

/// 学习批次会话（记录用户某次学习的断点状态）
class LearningSession {
  static const _uuid = Uuid();

  final String id;
  final String userId;
  final LearningSessionType sessionType;
  final String? serverSessionId;
  final String? bookId;

  /// 'active' | 'completed'
  final String status;
  final String dataPayload;
  final DateTime createdAt;

  LearningSession({
    required this.id,
    required this.userId,
    required this.sessionType,
    this.serverSessionId,
    this.bookId,
    required this.status,
    required this.dataPayload,
    required this.createdAt,
  });

  factory LearningSession.wordLearn({
    String? id,
    required int userId,
    String? serverSessionId,
    required String bookId,
    required String wordsPayload,
    required int currentIndex,
    required int batchStartSort,
    required int batchEndSort,
    String status = 'active',
    DateTime? createdAt,
  }) {
    final decodedWords = jsonDecode(wordsPayload) as List<dynamic>;

    return LearningSession(
      id: id ?? _uuid.v4(),
      userId: userId.toString(),
      sessionType: LearningSessionType.wordLearn,
      serverSessionId: serverSessionId,
      bookId: bookId,
      status: status,
      dataPayload: jsonEncode({
        'words': decodedWords,
        'word_states': <String, dynamic>{},
        'current_index': currentIndex,
        'batch_start_sort': batchStartSort,
        'batch_end_sort': batchEndSort,
      }),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory LearningSession.wordReview({
    String? id,
    required int userId,
    required String serverSessionId,
    required String dataPayload,
    String status = 'active',
    DateTime? createdAt,
  }) {
    return LearningSession(
      id: id ?? _uuid.v4(),
      userId: userId.toString(),
      sessionType: LearningSessionType.wordReview,
      serverSessionId: serverSessionId,
      bookId: null,
      status: status,
      dataPayload: dataPayload,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory LearningSession.kanaReview({
    String? id,
    required int userId,
    required String serverSessionId,
    required String dataPayload,
    String status = 'active',
    DateTime? createdAt,
  }) {
    return LearningSession(
      id: id ?? _uuid.v4(),
      userId: userId.toString(),
      sessionType: LearningSessionType.kanaReview,
      serverSessionId: serverSessionId,
      bookId: null,
      status: status,
      dataPayload: dataPayload,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory LearningSession.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at'];

    return LearningSession(
      id: map['id'] as String,
      userId: map['user_id'].toString(),
      sessionType: LearningSessionType.fromDbValue(
        map['session_type'] as String,
      ),
      serverSessionId: map['server_session_id'] as String?,
      bookId: map['book_id'] as String?,
      status: map['status'] as String,
      dataPayload: map['data_payload'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _normalizeEpochMilliseconds(rawCreatedAt),
      ),
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'id': id,
      'user_id': userId,
      'session_type': sessionType.dbValue,
      'server_session_id': serverSessionId,
      'book_id': bookId,
      'status': status,
      'data_payload': dataPayload,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    final map = toMapForInsert();
    map.remove('id');
    return map;
  }

  LearningSession copyWith({
    String? id,
    String? userId,
    LearningSessionType? sessionType,
    Object? serverSessionId = _sentinel,
    Object? bookId = _sentinel,
    String? dataPayload,
    Object? wordsPayload = _sentinel,
    int? currentIndex,
    int? batchStartSort,
    int? batchEndSort,
    String? status,
    DateTime? createdAt,
  }) {
    var nextDataPayload = dataPayload ?? this.dataPayload;
    if (currentIndex != null ||
        batchStartSort != null ||
        batchEndSort != null ||
        wordsPayload != _sentinel) {
      final nextPayload = decodedDataPayload;

      if (currentIndex != null) {
        nextPayload['current_index'] = currentIndex;
      }
      if (batchStartSort != null) {
        nextPayload['batch_start_sort'] = batchStartSort;
      }
      if (batchEndSort != null) {
        nextPayload['batch_end_sort'] = batchEndSort;
      }
      if (wordsPayload != _sentinel) {
        final value = wordsPayload as String?;
        nextPayload['words'] = value == null
            ? const <dynamic>[]
            : jsonDecode(value) as List<dynamic>;
      }

      nextDataPayload = jsonEncode(nextPayload);
    }

    return LearningSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionType: sessionType ?? this.sessionType,
      serverSessionId: serverSessionId == _sentinel
          ? this.serverSessionId
          : serverSessionId as String?,
      bookId: bookId == _sentinel ? this.bookId : bookId as String?,
      status: status ?? this.status,
      dataPayload: nextDataPayload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> get decodedDataPayload {
    return Map<String, dynamic>.from(
      jsonDecode(dataPayload) as Map<String, dynamic>,
    );
  }

  int? get localUserId => int.tryParse(userId);

  List<String> get wordIds {
    final words = decodedDataPayload['words'];
    if (words is! List<dynamic>) {
      return const <String>[];
    }

    return words
        .map((item) {
          if (item is! Map) {
            return null;
          }

          final map = Map<String, dynamic>.from(item);
          final directId = map['id'];
          if (directId is String && directId.isNotEmpty) {
            return directId;
          }

          final word = map['word'];
          if (word is Map) {
            final nestedId = word['id'];
            if (nestedId is String && nestedId.isNotEmpty) {
              return nestedId;
            }
          }

          return null;
        })
        .whereType<String>()
        .toList(growable: false);
  }

  String? get wordsPayload {
    if (sessionType != LearningSessionType.wordLearn) {
      return null;
    }

    final words = decodedDataPayload['words'];
    if (words is! List<dynamic>) {
      return null;
    }

    return jsonEncode(words);
  }

  int get currentIndex => _readInt(decodedDataPayload['current_index']);

  int get batchStartSort => _readInt(decodedDataPayload['batch_start_sort']);

  int get batchEndSort => _readInt(decodedDataPayload['batch_end_sort']);

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  static int _readInt(dynamic value) {
    return switch (value) {
      int number => number,
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }

  static int _normalizeEpochMilliseconds(dynamic value) {
    final raw = switch (value) {
      int number => number,
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };

    if (raw == 0) {
      return 0;
    }

    return raw < 1000000000000 ? raw * 1000 : raw;
  }
}
