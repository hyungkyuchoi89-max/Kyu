import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word.dart';

/// 단어별 학습 기록(틀린 횟수·본 횟수)을 기기에 저장한다.
///
/// 알람 퀴즈에서 틀린 단어는 [wrongCount]가 올라가고, 다음 순환에서 먼저
/// 다시 나온다. 나중에 그 단어를 맞히면 [wrongCount]가 하나씩 줄어서,
/// 완전히 익힌 단어는 자연스럽게 우선순위에서 빠진다.
///
/// 저장 형식(SharedPreferences, JSON):
/// ```json
/// { "wrong": { "elementary-0012": 2 }, "seen": { "elementary-0012": 5 } }
/// ```
class WordProgressService extends ChangeNotifier {
  WordProgressService._();

  static final WordProgressService instance = WordProgressService._();

  static const String _key = 'ww.wordProgress';

  final Map<String, int> _wrongCounts = <String, int>{};
  final Map<String, int> _seenCounts = <String, int>{};

  /// 단어 id → 지금까지 틀린 횟수(맞히면 1씩 줄어 0 밑으로 내려가지 않음).
  Map<String, int> get wrongCounts => Map<String, int>.unmodifiable(_wrongCounts);

  /// 단어 id → 퀴즈에서 만난 횟수.
  Map<String, int> get seenCounts => Map<String, int>.unmodifiable(_seenCounts);

  int wrongCountFor(String wordId) => _wrongCounts[wordId] ?? 0;

  int seenCountFor(String wordId) => _seenCounts[wordId] ?? 0;

  /// 아직 한 번이라도 틀린 단어 수.
  int get weakWordCount => _wrongCounts.length;

  /// 지금까지 틀린 총 횟수.
  int get totalWrong => _wrongCounts.values.fold(0, (int sum, int value) => sum + value);

  /// 자주 틀린 순서로 정렬한 단어 id 목록(많이 틀린 단어부터).
  List<String> get mostMissedIds {
    final List<String> ids = _wrongCounts.keys.toList();
    ids.sort((String a, String b) {
      final int diff = (_wrongCounts[b] ?? 0) - (_wrongCounts[a] ?? 0);
      return diff != 0 ? diff : a.compareTo(b);
    });
    return ids;
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _readCounts(decoded['wrong'], _wrongCounts);
      _readCounts(decoded['seen'], _seenCounts);
      notifyListeners();
    } catch (_) {
      // 저장된 값이 깨졌으면 빈 기록으로 시작한다.
      _wrongCounts.clear();
      _seenCounts.clear();
    }
  }

  /// 퀴즈 한 문제의 결과를 기록한다.
  Future<void> recordAnswer(Word word, {required bool correct}) async {
    final String id = word.id;
    if (id.isEmpty) {
      return;
    }
    _seenCounts[id] = (_seenCounts[id] ?? 0) + 1;
    final int current = _wrongCounts[id] ?? 0;
    if (correct) {
      if (current <= 1) {
        _wrongCounts.remove(id);
      } else {
        _wrongCounts[id] = current - 1;
      }
    } else {
      _wrongCounts[id] = current + 1;
    }
    notifyListeners();
    await _save();
  }

  /// 학습 기록을 모두 지운다(처음부터 다시).
  Future<void> reset() async {
    _wrongCounts.clear();
    _seenCounts.clear();
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  void _readCounts(Object? source, Map<String, int> target) {
    target.clear();
    if (source is! Map) {
      return;
    }
    source.forEach((Object? key, Object? value) {
      if (key is String && value is int && value > 0) {
        target[key] = value;
      }
    });
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(<String, dynamic>{
      'wrong': _wrongCounts,
      'seen': _seenCounts,
    });
    await prefs.setString(_key, raw);
  }
}
