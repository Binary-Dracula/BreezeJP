class Word {
  final int id;
  final String word;
  final String? furigana;
  final String? romaji;
  final String? jlptLevel;
  final String? partOfSpeech;
  final String? pitchAccent;

  Word({
    required this.id,
    required this.word,
    this.furigana,
    this.romaji,
    this.jlptLevel,
    this.partOfSpeech,
    this.pitchAccent,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      furigana: map['furigana'],
      romaji: map['romaji'],
      jlptLevel: map['jlpt_level'],
      partOfSpeech: map['part_of_speech'],
      pitchAccent: map['pitch_accent'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'furigana': furigana,
      'romaji': romaji,
      'jlpt_level': jlptLevel,
      'part_of_speech': partOfSpeech,
      'pitch_accent': pitchAccent,
    };
  }
}
