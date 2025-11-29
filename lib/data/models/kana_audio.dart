/// 五十音发音音频模型
class KanaAudio {
  final int id;
  final int? kanaId;
  final String? audioFilename;
  final String? source;
  final String? createdAt;

  KanaAudio({
    required this.id,
    this.kanaId,
    this.audioFilename,
    this.source,
    this.createdAt,
  });

  factory KanaAudio.fromMap(Map<String, dynamic> map) {
    return KanaAudio(
      id: map['id'],
      kanaId: map['kana_id'],
      audioFilename: map['audio_filename'],
      source: map['source'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'audio_filename': audioFilename,
      'source': source,
      'created_at': createdAt,
    };
  }
}
