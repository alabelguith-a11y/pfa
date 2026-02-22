import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/gesture_data.dart';

class GestureLoaderService {
  static GestureLibrary? _library;

  static Future<GestureLibrary> load() async {
    if (_library != null) return _library!;
    final String jsonString =
        await rootBundle.loadString('assets/gesture.json');
    final Map<String, dynamic> data =
        jsonDecode(jsonString) as Map<String, dynamic>;

    final Map<String, dynamic> alphabetMap =
        data['alphabet'] as Map<String, dynamic>? ?? {};
    final Map<String, GestureData> alphabet = {};
    for (final e in alphabetMap.entries) {
      alphabet[e.key] =
          GestureData.fromJson(Map<String, dynamic>.from(e.value as Map));
    }

    final Map<String, dynamic> wordsMap =
        data['words'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> words = {};
    for (final e in wordsMap.entries) {
      words[e.key] =
          (e.value as List<dynamic>).map((x) => x.toString()).toList();
    }

    _library = GestureLibrary(alphabet: alphabet, words: words);
    return _library!;
  }
}
