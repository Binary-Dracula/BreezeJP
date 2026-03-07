import 'dart:convert';

class GrammarContext {
  final int id;
  final int grammarId;
  final String? whenToUseCn;
  final String? whenToUseEn;

  /// limitation JSON String stored in db, decoded to List<String> in Dart
  final List<String> limitations;

  GrammarContext({
    required this.id,
    required this.grammarId,
    this.whenToUseCn,
    this.whenToUseEn,
    this.limitations = const [],
  });

  factory GrammarContext.fromMap(Map<String, dynamic> map) {
    String? parsedWhenToUseCn;
    List<String> parsedLimitations = [];

    final cnStr = map['when_to_use_cn'] as String?;
    if (cnStr != null && cnStr.isNotEmpty) {
      try {
        if (cnStr.startsWith('{')) {
          final decoded = jsonDecode(cnStr) as Map<String, dynamic>;
          parsedWhenToUseCn = decoded['when_to_use']?.toString();
          if (decoded['limitations'] is List) {
            parsedLimitations = (decoded['limitations'] as List)
                .map((e) => e.toString())
                .toList();
          }
        } else {
          // Fallback if it's just a raw string
          parsedWhenToUseCn = cnStr;
        }
      } catch (e) {
        parsedWhenToUseCn = cnStr;
      }
    }

    // Parse English field if necessary
    String? parsedWhenToUseEn;
    final enStr = map['when_to_use_en'] as String?;
    if (enStr != null && enStr.isNotEmpty) {
      try {
        if (enStr.startsWith('{')) {
          final decoded = jsonDecode(enStr) as Map<String, dynamic>;
          parsedWhenToUseEn = decoded['when_to_use']?.toString();
          // We prioritize limitations from CN, so we don't strictly parse en limitations unless we need them.
        } else {
          parsedWhenToUseEn = enStr;
        }
      } catch (e) {
        parsedWhenToUseEn = enStr;
      }
    }

    return GrammarContext(
      id: map['id'] as int,
      grammarId: map['grammar_id'] as int,
      whenToUseCn: parsedWhenToUseCn ?? map['when_to_use_cn'] as String?,
      whenToUseEn: parsedWhenToUseEn ?? map['when_to_use_en'] as String?,
      limitations: parsedLimitations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grammar_id': grammarId,
      'when_to_use_cn': whenToUseCn,
      'when_to_use_en': whenToUseEn,
      'limitations_json': limitations.isEmpty ? null : jsonEncode(limitations),
    };
  }

  GrammarContext copyWith({
    int? id,
    int? grammarId,
    String? whenToUseCn,
    String? whenToUseEn,
    List<String>? limitations,
  }) {
    return GrammarContext(
      id: id ?? this.id,
      grammarId: grammarId ?? this.grammarId,
      whenToUseCn: whenToUseCn ?? this.whenToUseCn,
      whenToUseEn: whenToUseEn ?? this.whenToUseEn,
      limitations: limitations ?? this.limitations,
    );
  }
}
