/// 五十音示例词汇模型
/// 用于辅助记忆假名
class KanaExample {
  final int id;
  final int? kanaId;
  final String? exampleJp;
  final String? exampleFurigana;
  final String? exampleCn;
  final String? createdAt;

  KanaExample({
    required this.id,
    this.kanaId,
    this.exampleJp,
    this.exampleFurigana,
    this.exampleCn,
    this.createdAt,
  });

  factory KanaExample.fromMap(Map<String, dynamic> map) {
    return KanaExample(
      id: map['id'],
      kanaId: map['kana_id'],
      exampleJp: map['example_jp'],
      exampleFurigana: map['example_furigana'],
      exampleCn: map['example_cn'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'example_jp': exampleJp,
      'example_furigana': exampleFurigana,
      'example_cn': exampleCn,
      'created_at': createdAt,
    };
  }
}
