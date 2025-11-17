class WordAudio {
  final int id;
  final int wordId;
  final String audioFilename;
  final String? voiceType;
  final String? source;

  WordAudio({
    required this.id,
    required this.wordId,
    required this.audioFilename,
    this.voiceType,
    this.source,
  });

  factory WordAudio.fromMap(Map<String, dynamic> map) {
    return WordAudio(
      id: map['id'],
      wordId: map['word_id'],
      audioFilename: map['audio_filename'],
      voiceType: map['voice_type'],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'audio_filename': audioFilename,
      'voice_type': voiceType,
      'source': source,
    };
  }
}
