/// 五十音字母模型
/// 存储平假名、片假名及其属性
class KanaLetter {
  final int id;
  final String kanaChar;
  final KanaScriptKind scriptKind;
  final String romaji;
  final String? consonant;
  final String vowel;
  final String? rowGroup;
  final String? kanaCategory;
  final int? displayOrder;
  final int? pairGroupId;
  final int? audioId;
  final String? mnemonic;
  final String createdAt;
  final String updatedAt;

  KanaLetter({
    required this.id,
    required this.kanaChar,
    required this.scriptKind,
    required this.romaji,
    this.consonant,
    required this.vowel,
    this.rowGroup,
    this.kanaCategory,
    this.displayOrder,
    this.pairGroupId,
    this.audioId,
    this.mnemonic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanaLetter.fromMap(Map<String, dynamic> map) {
    return KanaLetter(
      id: map['id'],
      kanaChar: map['kana_char'],
      scriptKind:
          KanaScriptKindX.fromString(map['script_kind'] as String? ?? 'hiragana'),
      romaji: map['romaji'],
      consonant: map['consonant'],
      vowel: map['vowel'],
      rowGroup: map['row_group'],
      kanaCategory: map['kana_category'],
      displayOrder: map['display_order'],
      pairGroupId: map['pair_group_id'],
      audioId: map['audio_id'],
      mnemonic: map['mnemonic'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_char': kanaChar,
      'script_kind': scriptKind.value,
      'romaji': romaji,
      'consonant': consonant,
      'vowel': vowel,
      'row_group': rowGroup,
      'kana_category': kanaCategory,
      'display_order': displayOrder,
      'pair_group_id': pairGroupId,
      'audio_id': audioId,
      'mnemonic': mnemonic,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

enum KanaScriptKind {
  hiragana,
  katakana,
}

extension KanaScriptKindX on KanaScriptKind {
  static KanaScriptKind fromString(String value) {
    switch (value) {
      case 'katakana':
        return KanaScriptKind.katakana;
      case 'hiragana':
      default:
        return KanaScriptKind.hiragana;
    }
  }

  String get value {
    switch (this) {
      case KanaScriptKind.katakana:
        return 'katakana';
      case KanaScriptKind.hiragana:
        return 'hiragana';
    }
  }
}
