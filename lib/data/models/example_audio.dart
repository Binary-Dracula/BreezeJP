class ExampleAudio {
  final int id;
  final int exampleId;
  final String audioFilename;
  final String? audioUrl;
  final String? voiceType;
  final String? source;

  ExampleAudio({
    required this.id,
    required this.exampleId,
    required this.audioFilename,
    this.audioUrl,
    this.voiceType,
    this.source,
  });

  factory ExampleAudio.fromMap(Map<String, dynamic> map) {
    return ExampleAudio(
      id: map['id'],
      exampleId: map['example_id'],
      audioFilename: map['audio_filename'],
      audioUrl: map['audio_url'],
      voiceType: map['voice_type'],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'example_id': exampleId,
      'audio_filename': audioFilename,
      'audio_url': audioUrl,
      'voice_type': voiceType,
      'source': source,
    };
  }
}
