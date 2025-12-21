class ExampleApiItem {
  final String text;
  final String? translation;
  final String source;
  final String? attribution;

  const ExampleApiItem({
    required this.text,
    this.translation,
    required this.source,
    this.attribution,
  });

  factory ExampleApiItem.fromMap(Map<String, dynamic> map) {
    return ExampleApiItem(
      text: map['text'] as String,
      translation: map['translation'] as String?,
      source: map['source'] as String,
      attribution: map['attribution'] as String?,
    );
  }
}
