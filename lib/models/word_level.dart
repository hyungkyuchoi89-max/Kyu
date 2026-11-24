/// 단어 난이도(레벨). `assets/words.json`의 `category` 값과 같다.
enum WordLevel {
  elementary('elementary', '초등영어'),
  middle('middle', '중등영어'),
  highSuneung('high_suneung', '고등수능영어'),
  toeic('toeic', '토익단어'),
  toefl('toefl', '토플단어');

  const WordLevel(this.key, this.label);

  /// words.json의 category 값
  final String key;

  /// 화면에 보이는 한국어 이름
  final String label;

  static WordLevel fromKey(String? key) {
    for (final WordLevel level in WordLevel.values) {
      if (level.key == key) {
        return level;
      }
    }
    return WordLevel.elementary;
  }
}
