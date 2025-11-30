/// 五十音笔顺数据模型
class KanaStrokeOrder {
  final int id;
  final int? kanaId;
  final String? hiraganaSvg;
  final String? katakanaSvg;

  KanaStrokeOrder({
    required this.id,
    this.kanaId,
    this.hiraganaSvg,
    this.katakanaSvg,
  });

  factory KanaStrokeOrder.fromMap(Map<String, dynamic> map) {
    return KanaStrokeOrder(
      id: map['id'],
      kanaId: map['kana_id'],
      hiraganaSvg: map['hiragana_svg'],
      katakanaSvg: map['katakana_svg'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'hiragana_svg': hiraganaSvg,
      'katakana_svg': katakanaSvg,
    };
  }
}
