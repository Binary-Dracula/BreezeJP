/// 五十音发音音频模型
class KanaAudio {
  final int id;
  final String audioFilename;
  final String? audioSource;
  final String createdAt;

  KanaAudio({
    required this.id,
    required this.audioFilename,
    this.audioSource,
    required this.createdAt,
  });

  factory KanaAudio.fromMap(Map<String, dynamic> map) {
    return KanaAudio(
      id: map['id'],
      audioFilename: map['audio_filename'],
      audioSource: map['audio_source'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audio_filename': audioFilename,
      'audio_source': audioSource,
      'created_at': createdAt,
    };
  }
}
