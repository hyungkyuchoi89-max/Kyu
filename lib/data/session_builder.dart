import 'dart:math' as math;

import '../models/study_plan.dart';
import '../models/word.dart';

/// 알람이 울린 뒤 진행되는 세션의 종류.
enum SessionMode {
  /// 새 단어 학습 → 퀴즈 (월~금)
  studyThenQuiz,

  /// 바로 퀴즈 (이지 플랜 금요일, 스파르타 플랜 주말, 매달 마지막 주 복습)
  quizOnly,
}

/// 오늘 알람에서 진행할 학습/퀴즈 계획.
class SessionPlan {
  const SessionPlan({
    required this.mode,
    required this.studyWords,
    required this.quizPool,
    required this.quizTarget,
    required this.title,
    required this.subtitle,
    this.isMonthlyReview = false,
  });

  final SessionMode mode;

  /// 학습 모드에서 한 문제씩 보여줄 단어들 (퀴즈 전용이면 비어 있음)
  final List<Word> studyWords;

  /// 퀴즈 문제를 뽑을 단어 풀
  final List<Word> quizPool;

  /// 알람을 끄기 위해 맞혀야 하는 정답 개수
  final int quizTarget;

  final String title;
  final String subtitle;

  /// 매달 마지막 주 복습(그 달에 배운 단어 전체)인지
  final bool isMonthlyReview;

  bool get hasStudy => studyWords.isNotEmpty;

  int get studyCount => studyWords.length;
}

/// 플랜·요일·레벨에 따라 오늘의 세션을 만든다.
///
/// 단어 배분은 "주 단위 회전" 방식이다.
/// - 매주 20칸씩 시작 위치가 밀려서 같은 요일이라도 주마다 다른 단어를 만난다.
/// - 한 주 안에서 월~금은 서로 겹치지 않는 20개씩을 배정받아 100개를 모두 채운다.
/// - 풀을 끝까지 돌면 처음으로 이어 붙여 **끊임없이 계속 돈다**(단어가 떨어지지 않음).
///
/// 오답 가중 순환:
/// - [wrongCounts]에 틀린 횟수가 있는 단어는, 풀을 한 바퀴 다 돈 다음 순환부터
///   앞쪽에 배치된다. 많이 틀린 단어일수록 더 자주, 더 먼저 다시 만난다.
/// - 맞혀서 횟수가 0이 되면 다시 일반 순서로 돌아간다.
///
/// 매달 마지막 주의 금요일(이지) / 토·일요일(스파르타)은 그 달에 배운 단어를
/// 모두 모은 "월간 복습"으로 출제 범위를 넓힌다.
class SessionBuilder {
  const SessionBuilder._();

  static const int wordsPerDay = 20;

  /// 기준일: 2024-01-01(월요일)
  static final DateTime _epoch = DateTime(2024, 1, 1);

  static int weekIndex(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return day.difference(_epoch).inDays ~/ 7;
  }

  /// 오늘까지 단어 풀을 몇 바퀴 돌았는지(0이면 첫 순환).
  static int cycleIndex(List<Word> pool, DateTime date) {
    if (pool.isEmpty) {
      return 0;
    }
    return (weekIndex(date) * wordsPerDay) ~/ pool.length;
  }

  /// 오답이 많은 단어를 앞으로 당긴 순서.
  ///
  /// 틀린 횟수가 0인 단어는 원래(쉬운 단어 → 어려운 단어) 순서를 그대로 지킨다.
  static List<Word> priorityOrder(
    List<Word> pool,
    Map<String, int> wrongCounts,
  ) {
    if (pool.isEmpty || wrongCounts.isEmpty) {
      return pool;
    }
    final List<int> indexes = List<int>.generate(pool.length, (int index) => index);
    indexes.sort((int a, int b) {
      final int weightA = wrongCounts[pool[a].id] ?? 0;
      final int weightB = wrongCounts[pool[b].id] ?? 0;
      if (weightA != weightB) {
        return weightB.compareTo(weightA);
      }
      return a.compareTo(b);
    });
    return List<Word>.generate(
      pool.length,
      (int index) => pool[indexes[index]],
      growable: false,
    );
  }

  /// 이번 주에 볼 단어 100개(순서대로). 풀을 다 돌면 처음으로 이어 붙인다.
  static List<Word> weekWords(
    List<Word> pool,
    DateTime date, {
    Map<String, int> wrongCounts = const <String, int>{},
  }) {
    if (pool.isEmpty) {
      return const <Word>[];
    }
    final List<Word> ordered = cycleIndex(pool, date) == 0
        ? pool
        : priorityOrder(pool, wrongCounts);
    final int total = ordered.length;
    final int start = (weekIndex(date) * wordsPerDay) % total;
    final int count = math.min(total, wordsPerDay * 5);
    return List<Word>.generate(
      count,
      (int index) => ordered[(start + index) % total],
      growable: false,
    );
  }

  /// [date]가 속한 주의 [dayIndex](월=0 ~ 일=6)에 배정된 단어들.
  static List<Word> dailyWords(
    List<Word> pool,
    DateTime date,
    int dayIndex, {
    Map<String, int> wrongCounts = const <String, int>{},
  }) {
    if (pool.isEmpty || dayIndex < 0) {
      return const <Word>[];
    }
    final List<Word> week = weekWords(pool, date, wrongCounts: wrongCounts);
    final int start = dayIndex * wordsPerDay;
    final int count = math.min(wordsPerDay, week.length);
    return List<Word>.generate(
      count,
      (int index) => week[(start + index) % week.length],
      growable: false,
    );
  }

  /// [date]가 속한 주의 [fromDayIndex]~[toDayIndex] 단어를 모두 모은다.
  static List<Word> weekPool(
    List<Word> pool,
    DateTime date,
    int fromDayIndex,
    int toDayIndex, {
    Map<String, int> wrongCounts = const <String, int>{},
  }) {
    final List<Word> result = <Word>[];
    for (int day = fromDayIndex; day <= toDayIndex; day++) {
      result.addAll(dailyWords(pool, date, day, wrongCounts: wrongCounts));
    }
    return result;
  }

  /// [date]가 속한 주가 그 달의 "마지막 주"인지.
  ///
  /// 같은 요일이 다음 주로 넘어가면, 오늘이 그 달의 마지막 그 요일이다.
  /// 예: 2026-11-27(금) + 7일 = 2026-12-04 → 11월의 마지막 금요일.
  /// 이지 플랜의 마지막 금요일, 스파르타 플랜의 마지막 토·일요일에 월간 복습을 한다.
  static bool isLastWeekOfMonth(DateTime date) {
    final DateTime sameWeekdayNextWeek =
        DateTime(date.year, date.month, date.day).add(const Duration(days: 7));
    return sameWeekdayNextWeek.month != date.month;
  }

  /// 그 달 1일부터 [date] 전날까지 월~금에 배정된 단어를 모두 모은다.
  ///
  /// "그 달에 지금까지 배운 단어"를 그대로 이어 붙이므로, 같은 단어가 여러 번
  /// 들어갈 수 있다(주 단위 회전 때문에 한 주에 100개를 다 보기 때문).
  /// 월간 복습에서는 이 풀 전체에서 문제를 내고, 퀴즈 엔진이 오답 단어를 먼저 낸다.
  static List<Word> monthPool(
    List<Word> pool,
    DateTime date, {
    Map<String, int> wrongCounts = const <String, int>{},
  }) {
    if (pool.isEmpty) {
      return const <Word>[];
    }
    final DateTime firstDay = DateTime(date.year, date.month, 1);
    final DateTime lastStudied = DateTime(date.year, date.month, date.day)
        .subtract(const Duration(days: 1));
    final List<Word> result = <Word>[];
    DateTime day = firstDay;
    while (!day.isAfter(lastStudied)) {
      if (day.weekday >= DateTime.monday && day.weekday <= DateTime.friday) {
        result.addAll(
          dailyWords(pool, day, day.weekday - 1, wrongCounts: wrongCounts),
        );
      }
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  static SessionPlan build({
    required StudyPlan plan,
    required List<Word> levelWords,
    required DateTime now,
    Map<String, int> wrongCounts = const <String, int>{},
  }) {
    final int weekday = now.weekday;
    final bool monthlyReview = isLastWeekOfMonth(now);

    if (weekday <= DateTime.friday) {
      if (plan == StudyPlan.easy && weekday == DateTime.friday) {
        final List<Word> pool = monthlyReview
            ? monthPool(levelWords, now, wrongCounts: wrongCounts)
            : weekPool(levelWords, now, 0, 3, wrongCounts: wrongCounts);
        return SessionPlan(
          mode: SessionMode.quizOnly,
          studyWords: const <Word>[],
          quizPool: pool,
          quizTarget: 10,
          isMonthlyReview: monthlyReview,
          title: monthlyReview ? '이번 달 마지막 복습 퀴즈' : '이번 주 복습 퀴즈',
          subtitle: monthlyReview
              ? '이번 달에 배운 단어 ${pool.length}개에서 10문제를 맞히면 알람이 꺼져요'
              : '월~목에 배운 ${pool.length}개 단어 · 10문제를 맞히면 알람이 꺼져요',
        );
      }

      final List<Word> today =
          dailyWords(levelWords, now, weekday - 1, wrongCounts: wrongCounts);
      return SessionPlan(
        mode: SessionMode.studyThenQuiz,
        studyWords: today,
        quizPool: today,
        quizTarget: 5,
        title: '오늘의 단어 ${today.length}',
        subtitle: '단어를 본 뒤 5문제를 맞히면 알람이 꺼져요',
      );
    }

    if (plan == StudyPlan.sparta) {
      final List<Word> pool = monthlyReview
          ? monthPool(levelWords, now, wrongCounts: wrongCounts)
          : weekPool(levelWords, now, 0, 4, wrongCounts: wrongCounts);
      return SessionPlan(
        mode: SessionMode.quizOnly,
        studyWords: const <Word>[],
        quizPool: pool,
        quizTarget: 20,
        isMonthlyReview: monthlyReview,
        title: monthlyReview ? '이번 달 마지막 복습 퀴즈' : '주말 복습 퀴즈',
        subtitle: monthlyReview
            ? '이번 달에 배운 단어 ${pool.length}개에서 20문제를 맞히면 알람이 꺼져요'
            : '이번 주 ${pool.length}개 단어 · 20문제를 맞히면 알람이 꺼져요',
      );
    }

    // 이지 플랜의 주말: 알람은 없지만 '미리보기'로 실행하면 복습 퀴즈를 제공한다.
    final List<Word> easyReviewPool = monthlyReview
        ? monthPool(levelWords, now, wrongCounts: wrongCounts)
        : weekPool(levelWords, now, 0, 3, wrongCounts: wrongCounts);
    return SessionPlan(
      mode: SessionMode.quizOnly,
      studyWords: const <Word>[],
      quizPool: easyReviewPool,
      quizTarget: 10,
      isMonthlyReview: monthlyReview,
      title: monthlyReview ? '이번 달 마지막 복습 퀴즈' : '주말 복습 퀴즈',
      subtitle: '이지 플랜은 주말 알람이 없어요 · ${easyReviewPool.length}개 단어에서 10문제',
    );
  }
}
