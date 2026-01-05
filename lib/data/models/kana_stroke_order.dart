/// 五十音笔顺数据模型
class KanaStrokeOrder {
  final int id;
  final int? kanaId;
  final String? svg;

  KanaStrokeOrder({
    required this.id,
    this.kanaId,
    this.svg,
  });

  factory KanaStrokeOrder.fromMap(Map<String, dynamic> map) {
    return KanaStrokeOrder(
      id: map['id'],
      kanaId: map['kana_id'],
      svg: map['svg'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'svg': svg,
    };
  }
}
