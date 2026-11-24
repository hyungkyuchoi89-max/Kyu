import 'dart:math';

import '../models/word.dart';

/// 2지선다 퀴즈 한 문제.
///
/// 한국어 뜻([answer].meaning)을 보여주고 두 개의 영어 단어 중 정답을 고르게 한다.
class QuizQuestion {
  const QuizQuestion({required this.answer, required this.options});

  final Word answer;

  /// 길이 2. 하나는 [answer], 하나는 오답.
  final List<Word> options;
}

/// 단어 풀에서 문제를 계속 뽑아 주는 엔진.
///
/// - 풀을 한 번 다 쓰면 다시 섞어서 이어 간다(끝없이 반복, 단어가 떨어지지 않음).
/// - [wrongCounts]에 틀린 횟수가 있으면 그 단어를 다음 바퀴에서 먼저 낸다.
///   (많이 틀린 단어일수록 앞으로, 같은 횟수끼리는 무작위)
class QuizEngine {
  QuizEngine({
    required List<Word> pool,
    int? seed,
    Map<String, int> wrongCounts = const <String, int>{},
  })  : _pool = List<Word>.unmodifiable(pool),
        _wrongCounts = Map<String, int>.unmodifiable(wrongCounts),
        _random = Random(seed);

  final List<Word> _pool;
  final Map<String, int> _wrongCounts;
  final Random _random;
  final List<Word> _queue = <Word>[];

  String? _lastServedId;

  bool get isEmpty => _pool.isEmpty;

  /// 오답 가중치(많이 틀릴수록 큰 값, 최대 5).
  int _weightOf(Word word) {
    final int count = _wrongCounts[word.id] ?? 0;
    return count > 5 ? 5 : count;
  }

  QuizQuestion next() {
    if (_pool.isEmpty) {
      throw StateError('퀴즈 풀이 비어 있습니다.');
    }
    if (_queue.isEmpty) {
      _refill();
    }
    final Word answer = _queue.removeAt(0);
    _lastServedId = answer.id;
    final List<Word> options = <Word>[answer, _pickDistractor(answer)];
    options.shuffle(_random);
    return QuizQuestion(answer: answer, options: List<Word>.unmodifiable(options));
  }

  void _refill() {
    // 먼저 무작위로 섞고, 그 순서를 유지한 채 틀린 횟수가 많은 단어를 앞으로 올린다.
    final List<int> order = List<int>.generate(_pool.length, (int index) => index)
      ..shuffle(_random);
    final Map<int, int> shuffledRank = <int, int>{
      for (int rank = 0; rank < order.length; rank++) order[rank]: rank,
    };
    order.sort((int a, int b) {
      final int byWeight = _weightOf(_pool[b]).compareTo(_weightOf(_pool[a]));
      return byWeight != 0 ? byWeight : shuffledRank[a]!.compareTo(shuffledRank[b]!);
    });

    _queue
      ..clear()
      ..addAll(order.map((int index) => _pool[index]));

    // 풀을 다 쓰고 다시 시작할 때 바로 앞 문제가 또 나오지 않게 한다.
    if (_queue.length > 1 && _lastServedId != null && _queue.first.id == _lastServedId) {
      final Word first = _queue.first;
      _queue[0] = _queue[1];
      _queue[1] = first;
    }
  }

  Word _pickDistractor(Word answer) {
    Word candidate = _pool[_random.nextInt(_pool.length)];
    for (int attempt = 0; attempt < 24; attempt++) {
      if (candidate.id != answer.id && candidate.word.toLowerCase() != answer.word.toLowerCase()) {
        return candidate;
      }
      candidate = _pool[_random.nextInt(_pool.length)];
    }
    for (final Word word in _pool) {
      if (word.id != answer.id && word.word.toLowerCase() != answer.word.toLowerCase()) {
        return word;
      }
    }
    return answer;
  }
}
