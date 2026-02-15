class ConjugationType {
  final int id;
  final String code;
  final String nameJa;
  final String nameCn;
  final int sortOrder;
  final String? description;

  ConjugationType({
    required this.id,
    required this.code,
    required this.nameJa,
    required this.nameCn,
    this.sortOrder = 0,
    this.description,
  });

  factory ConjugationType.fromMap(Map<String, dynamic> map) {
    return ConjugationType(
      id: map['id'] as int,
      code: map['code'] as String,
      nameJa: map['name_ja'] as String,
      nameCn: map['name_cn'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name_ja': nameJa,
      'name_cn': nameCn,
      'sort_order': sortOrder,
      'description': description,
    };
  }
}
