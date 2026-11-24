import 'package:flutter_test/flutter_test.dart';
import 'package:word_alarm_app/data/quiz_engine.dart';
import 'package:word_alarm_app/data/session_builder.dart';
import 'package:word_alarm_app/models/study_plan.dart';
import 'package:word_alarm_app/models/word.dart';

List<Word> buildPool([String category = 'elementary']) {
  return List<Word>.generate(100, (int index) {
    return Word(
      id: 'w$index',
      category: category,
      word: 'word$index',
      phonetic: '/wɜːrd$index/',
      meaning: '뜻$index',
      example: 'This is example $index.',
    );
  });
}

void main() {
  // 2026-11-23은 월요일이다.
  final DateTime monday = DateTime(2026, 11, 23);
  final List<Word> pool = buildPool();

  group('이지 플랜', () {
    test('월요일은 20개 학습 후 5문제', () {
      final SessionPlan session = SessionBuilder.build(
        plan: StudyPlan.easy,
        levelWords: pool,
        now: monday,
      );
      expect(session.mode, SessionMode.studyThenQuiz);
      expect(session.studyCount, 20);
      expect(session.quizPool.length, 20);
      expect(session.quizTarget, 5);
      expect(session.isMonthlyReview, isFalse);
    });

    test('평범한 주 금요일은 이번 주 80개에서 10문제', () {
      final SessionPlan session = SessionBuilder.build(
        plan: StudyPlan.easy,
        levelWords: pool,
        now: DateTime(2026, 11, 13),
      );
      expect(session.mode, SessionMode.quizOnly);
      expect(session.studyCount, 0);
      expect(session.quizPool.length, 80);
      expect(session.quizTarget, 10);
      expect(session.isMonthlyReview, isFalse);
    });

    test('매달 마지막 금요일은 그 달에 배운 단어 전체에서 10문제', () {
      final DateTime lastFriday = DateTime(2026, 11, 27);
      final SessionPlan session = SessionBuilder.build(
        plan: StudyPlan.easy,
        levelWords: pool,
        now: lastFriday,
      );
      expect(session.isMonthlyReview, isTrue);
      expect(session.mode, SessionMode.quizOnly);
      expect(session.quizTarget, 10);
      // 11월 2일~26일의 평일 19일 × 20단어
      expect(session.quizPool.length, 380);
    });

    test('토요일은 알람 대상이 아니다', () {
      expect(StudyPlan.easy.isActiveWeekday(DateTime.saturday), isFalse);
      expect(StudyPlan.easy.isActiveWeekday(DateTime.sunday), isFalse);
    });
  });

  group('스파르타 플랜', () {
    test('월~금은 학습 후 5문제', () {
      for (int offset = 0; offset < 5; offset++) {
        final SessionPlan session = SessionBuilder.build(
          plan: StudyPlan.sparta,
          levelWords: pool,
          now: monday.add(Duration(days: offset)),
        );
        expect(session.mode, SessionMode.studyThenQuiz);
        expect(session.studyCount, 20);
        expect(session.quizTarget, 5);
      }
    });

    test('평범한 주 토·일요일은 100개에서 20문제', () {
      for (final DateTime day in <DateTime>[
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 15),
      ]) {
        final SessionPlan session = SessionBuilder.build(
          plan: StudyPlan.sparta,
          levelWords: pool,
          now: day,
        );
        expect(session.mode, SessionMode.quizOnly);
        expect(session.quizPool.length, 100);
        expect(session.quizTarget, 20);
        expect(session.isMonthlyReview, isFalse);
        expect(StudyPlan.sparta.isActiveWeekday(day.weekday), isTrue);
      }
    });

    test('매달 마지막 토·일요일은 그 달에 배운 단어 전체에서 20문제', () {
      final SessionPlan saturday = SessionBuilder.build(
        plan: StudyPlan.sparta,
        levelWords: pool,
        now: DateTime(2026, 11, 28),
      );
      expect(saturday.isMonthlyReview, isTrue);
      expect(saturday.quizPool.length, 400); // 11월 2일~27일 평일 20일 × 20단어
      expect(saturday.quizTarget, 20);

      final SessionPlan sunday = SessionBuilder.build(
        plan: StudyPlan.sparta,
        levelWords: pool,
        now: DateTime(2026, 11, 29),
      );
      expect(sunday.isMonthlyReview, isTrue);
      expect(sunday.quizPool.length, 400);
    });
  });

  group('마지막 주 판정', () {
    test('그 달의 마지막 금/토/일요일만 true', () {
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 11, 20)), isFalse);
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 11, 27)), isTrue);
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 11, 28)), isTrue);
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 11, 29)), isTrue);
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 12, 4)), isFalse);
    });

    test('월말이 일요일인 달도 처리한다 (2026년 5월)', () {
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 5, 29)), isTrue);
      expect(SessionBuilder.isLastWeekOfMonth(DateTime(2026, 5, 31)), isTrue);
    });
  });

  test('한 주 월~금 5일은 겹치지 않는 100개를 채운다', () {
    final Set<String> ids = <String>{};
    for (int dayIndex = 0; dayIndex < 5; dayIndex++) {
      for (final Word word in SessionBuilder.dailyWords(pool, monday, dayIndex)) {
        ids.add(word.id);
      }
    }
    expect(ids.length, 100);
  });

  test('월간 복습 풀은 그 달에 배운 단어를 모두 담는다', () {
    final List<Word> monthPool =
        SessionBuilder.monthPool(pool, DateTime(2026, 11, 28));
    expect(monthPool.length, 400);
    expect(monthPool.every((Word word) => word.id.startsWith('w')), isTrue);
  });

  test('다음 주에는 다른 20개가 배정된다', () {
    final List<Word> thisWeek = SessionBuilder.dailyWords(pool, monday, 0);
    final List<Word> nextWeek =
        SessionBuilder.dailyWords(pool, monday.add(const Duration(days: 7)), 0);
    expect(thisWeek.map((Word w) => w.id).toList(),
        isNot(equals(nextWeek.map((Word w) => w.id).toList())));
  });

  test('퀴즈는 정답과 서로 다른 오답 하나를 낸다', () {
    final QuizEngine engine = QuizEngine(pool: pool, seed: 7);
    for (int i = 0; i < 30; i++) {
      final QuizQuestion question = engine.next();
      expect(question.options.length, 2);
      expect(
        question.options.first.id == question.answer.id ||
            question.options.last.id == question.answer.id,
        isTrue,
      );
      final Word other = question.options.first.id == question.answer.id
          ? question.options.last
          : question.options.first;
      expect(other.id, isNot(question.answer.id));
    }
  });

  test('풀을 다 쓴 뒤에도 계속 문제를 낼 수 있다', () {
    final QuizEngine engine = QuizEngine(pool: pool.sublist(0, 5), seed: 3);
    for (int i = 0; i < 25; i++) {
      final QuizQuestion question = engine.next();
      expect(question.answer.word.isNotEmpty, isTrue);
      expect(question.options.length, 2);
    }
  });

  group('오답 가중 순환', () {
    test('오답이 많은 단어를 풀의 앞쪽으로 당긴다', () {
      final List<Word> ordered = SessionBuilder.priorityOrder(
        pool,
        <String, int>{'w99': 3, 'w98': 1, 'w97': 3},
      );
      expect(ordered.length, pool.length);
      expect(ordered[0].id, 'w97');
      expect(ordered[1].id, 'w99');
      expect(ordered[2].id, 'w98');
      // 틀린 적 없는 단어는 원래 순서를 지킨다.
      expect(ordered[3].id, 'w0');
    });

    test('첫 순환에서는 오답 기록이 있어도 원래 순서를 지킨다', () {
      // 2024-01-01(월)은 기준일이라 첫 순환 시작점이다.
      final DateTime firstDay = DateTime(2024, 1, 1);
      expect(SessionBuilder.cycleIndex(pool, firstDay), 0);
      final List<Word> firstWeek = SessionBuilder.dailyWords(
        pool,
        firstDay,
        0,
        wrongCounts: <String, int>{'w75': 5},
      );
      expect(firstWeek.first.id, 'w0');
    });

    test('한 바퀴를 돈 뒤에는 오답 단어가 그날 제일 먼저 나온다', () {
      // 2024-02-05(월): 기준일에서 5주째 → 100단어 풀을 꽉 한 바퀴 돈 시점
      final DateTime fifthWeekMonday = DateTime(2024, 2, 5);
      expect(SessionBuilder.cycleIndex(pool, fifthWeekMonday), 1);

      final List<Word> laterCycle = SessionBuilder.dailyWords(
        pool,
        fifthWeekMonday,
        0,
        wrongCounts: <String, int>{'w75': 5},
      );
      expect(laterCycle.length, SessionBuilder.wordsPerDay);
      expect(laterCycle.first.id, 'w75');
    });

    test('단어가 떨어지지 않고 몇 바퀴든 계속 돈다', () {
      for (int week = 0; week < 120; week++) {
        final DateTime day = monday.add(Duration(days: week * 7));
        final List<Word> words = SessionBuilder.dailyWords(
          pool,
          day,
          0,
          wrongCounts: <String, int>{'w42': 2},
        );
        expect(words.length, SessionBuilder.wordsPerDay);
      }
    });

    test('풀이 20개보다 작아도 있는 만큼만 낸다', () {
      final List<Word> tiny = pool.sublist(0, 7);
      final List<Word> words = SessionBuilder.dailyWords(tiny, monday, 3);
      expect(words.length, 7);
      expect(words.map((Word w) => w.id).toSet().length, 7);
    });

    test('퀴즈 엔진은 오답 단어를 먼저 낸다', () {
      final QuizEngine engine = QuizEngine(
        pool: pool,
        seed: 5,
        wrongCounts: <String, int>{'w50': 4},
      );
      expect(engine.next().answer.id, 'w50');
    });

    test('한 바퀴 순환해도 퀴즈는 목표 정답까지 계속 낸다', () {
      final QuizEngine engine = QuizEngine(
        pool: pool.sublist(0, 5),
        seed: 9,
        wrongCounts: <String, int>{'w2': 3},
      );
      final List<String> served = <String>[];
      for (int i = 0; i < 30; i++) {
        served.add(engine.next().answer.id);
      }
      expect(served.length, 30);
      expect(served.first, 'w2');
    });
  });
}
