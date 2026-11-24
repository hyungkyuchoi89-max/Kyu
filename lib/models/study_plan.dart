/// 학습 플랜.
///
/// - 이지 플랜(월~금): 월~목은 20개 학습 후 퀴즈 5문제, 금요일은 배운 80개에서 퀴즈 10문제.
/// - 스파르타 플랜(월~일): 월~금은 20개 학습 후 퀴즈 5문제, 토~일은 배운 100개에서 퀴즈 20문제.
enum StudyPlan {
  easy(
    key: 'easy',
    label: '이지 플랜',
    daysLabel: '월~금',
    summary: '월~목 단어 학습 + 퀴즈, 금요일은 복습 퀴즈만',
  ),
  sparta(
    key: 'sparta',
    label: '스파르타 플랜',
    daysLabel: '월~일',
    summary: '월~금 단어 학습 + 퀴즈, 주말은 100단어 복습 퀴즈',
  );

  const StudyPlan({
    required this.key,
    required this.label,
    required this.daysLabel,
    required this.summary,
  });

  final String key;
  final String label;
  final String daysLabel;
  final String summary;

  static StudyPlan fromKey(String? key) {
    for (final StudyPlan plan in StudyPlan.values) {
      if (plan.key == key) {
        return plan;
      }
    }
    return StudyPlan.easy;
  }

  /// 이 플랜에서 알람이 울리는 요일인지. [weekday]는 DateTime.monday(1) ~ DateTime.sunday(7).
  bool isActiveWeekday(int weekday) {
    switch (this) {
      case StudyPlan.easy:
        return weekday >= DateTime.monday && weekday <= DateTime.friday;
      case StudyPlan.sparta:
        return weekday >= DateTime.monday && weekday <= DateTime.sunday;
    }
  }

  /// 새 단어를 학습하는 요일인지(월~금).
  bool isStudyWeekday(int weekday) =>
      weekday >= DateTime.monday && weekday <= DateTime.friday;
}
