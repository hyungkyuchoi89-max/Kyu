/// 단어 한 개. `assets/words.json`의 한 항목과 1:1로 대응한다.
class Word {
  const Word({
    required this.id,
    required this.category,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
  });

  /// 예: `elementary-001`
  final String id;

  /// `elementary`, `middle`, `high_suneung`, `toeic`, `toefl`
  final String category;

  /// 영어 스펠링
  final String word;

  /// 발음기호(IPA). 예: `/ˈæp.əl/`
  final String phonetic;

  /// 한국어 뜻
  final String meaning;

  /// 간단한 영어 예문
  final String example;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: (json['id'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      word: (json['word'] as String?) ?? '',
      phonetic: (json['phonetic'] as String?) ?? '',
      meaning: (json['meaning'] as String?) ?? '',
      example: (json['example'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category,
        'word': word,
        'phonetic': phonetic,
        'meaning': meaning,
        'example': example,
      };

  @override
  String toString() => 'Word($id: $word)';
}
