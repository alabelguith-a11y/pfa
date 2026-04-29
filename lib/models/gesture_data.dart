class GestureData {
  final String id;
  final double speed;
  final int durationMs;
  final List<int> angles;

  const GestureData({
    required this.id,
    this.speed = 0.6,
    this.durationMs = 400,
    required this.angles,
  });

  factory GestureData.fromJson(Map<String, dynamic> json) {
    return GestureData(
      id: json['id'] as String,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.6,
      durationMs: (json['duration_ms'] as int?) ?? 400,
      angles: (json['angles'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [0, 0, 0, 0, 0],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'speed': speed,
        'duration_ms': durationMs,
        'angles': angles,
      };

  String toCommandFrame() {
    final anglesJson = angles.map((a) => a.toString()).join(',');
    return '{"id":"$id","speed":$speed,"angles":[${anglesJson}]}';
  }
}

class GestureLibrary {
  final Map<String, GestureData> alphabet;
  final Map<String, List<String>> words;

  const GestureLibrary({
    required this.alphabet,
    required this.words,
  });

  List<String>? wordToSequence(String word) => words[word.toUpperCase()];

  GestureData? letterGesture(String letter) =>
      alphabet[letter.toUpperCase()];

  List<String> get wordList => words.keys.toList()..sort();
}
