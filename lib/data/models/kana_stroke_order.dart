/// 五十音笔顺数据模型
class KanaStrokeOrder {
  final int id;
  final int? kanaId;
  final String? strokeSvg;
  final String? createdAt;

  KanaStrokeOrder({
    required this.id,
    this.kanaId,
    this.strokeSvg,
    this.createdAt,
  });

  factory KanaStrokeOrder.fromMap(Map<String, dynamic> map) {
    return KanaStrokeOrder(
      id: map['id'],
      kanaId: map['kana_id'],
      strokeSvg: map['stroke_svg'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'stroke_svg': strokeSvg,
      'created_at': createdAt,
    };
  }
}
