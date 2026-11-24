import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';
import '../models/word_level.dart';

/// `assets/words.json`을 한 번만 읽어 메모리에 보관한다.
///
/// 파일 구조:
/// ```json
/// { "version": 1, "count": 7531, "words": [ { "id": "...", ... } ] }
/// ```
class WordRepository {
  WordRepository._();

  static final WordRepository instance = WordRepository._();

  List<Word> _all = const <Word>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  int get totalCount => _all.length;

  List<Word> get all => _all;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final String raw = await rootBundle.loadString('assets/words.json');
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('words.json의 최상위는 객체여야 합니다.');
    }
    final Object? list = decoded['words'];
    if (list is! List<dynamic>) {
      throw const FormatException('words.json에 words 배열이 없습니다.');
    }
    _all = list
        .whereType<Map<String, dynamic>>()
        .map(Word.fromJson)
        .where((Word word) => word.word.isNotEmpty)
        .toList(growable: false);
    _loaded = true;
  }

  /// 특정 레벨의 단어 목록. levelWords는 파일에 저장된 순서를 유지한다.
  List<Word> byLevel(WordLevel level) {
    return _all
        .where((Word word) => word.category == level.key)
        .toList(growable: false);
  }

  int countOf(WordLevel level) => byLevel(level).length;
}
