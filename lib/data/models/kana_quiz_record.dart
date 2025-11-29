/// 五十音测验记录模型
class KanaQuizRecord {
  final int id;
  final int? kanaId;
  final int? correct;
  final String? createdAt;

  KanaQuizRecord({required this.id, this.kanaId, this.correct, this.createdAt});

  /// 是否答对
  bool get isCorrect => correct == 1;

  factory KanaQuizRecord.fromMap(Map<String, dynamic> map) {
    return KanaQuizRecord(
      id: map['id'],
      kanaId: map['kana_id'],
      correct: map['correct'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'correct': correct,
      'created_at': createdAt,
    };
  }
}
