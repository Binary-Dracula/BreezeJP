/// 五十音字母模型
/// 存储平假名、片假名及其属性
class KanaLetter {
  final int id;
  final String? hiragana;
  final String? katakana;
  final String? romaji;
  final String? consonant;
  final String? vowel;
  final String? kanaGroup;
  final String? type;
  final int? sortIndex;
  final String? mnemonic;
  final String? createdAt;
  final String? updatedAt;

  KanaLetter({
    required this.id,
    this.hiragana,
    this.katakana,
    this.romaji,
    this.consonant,
    this.vowel,
    this.kanaGroup,
    this.type,
    this.sortIndex,
    this.mnemonic,
    this.createdAt,
    this.updatedAt,
  });

  factory KanaLetter.fromMap(Map<String, dynamic> map) {
    return KanaLetter(
      id: map['id'],
      hiragana: map['hiragana'],
      katakana: map['katakana'],
      romaji: map['romaji'],
      consonant: map['consonant'],
      vowel: map['vowel'],
      kanaGroup: map['kana_group'],
      type: map['type'],
      sortIndex: map['sort_index'],
      mnemonic: map['mnemonic'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hiragana': hiragana,
      'katakana': katakana,
      'romaji': romaji,
      'consonant': consonant,
      'vowel': vowel,
      'kana_group': kanaGroup,
      'type': type,
      'sort_index': sortIndex,
      'mnemonic': mnemonic,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
