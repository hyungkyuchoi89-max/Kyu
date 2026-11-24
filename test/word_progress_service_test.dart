import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_alarm_app/models/word.dart';
import 'package:word_alarm_app/services/word_progress_service.dart';

Word word(String id) => Word(
      id: id,
      category: 'elementary',
      word: 'test$id',
      phonetic: '/test/',
      meaning: '시험',
      example: 'This is a test.',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await WordProgressService.instance.reset();
  });

  test('틀리면 오답 횟수가 늘고, 맞히면 하나씩 줄어 0에서 멈춘다', () async {
    final WordProgressService service = WordProgressService.instance;

    await service.recordAnswer(word('a'), correct: false);
    await service.recordAnswer(word('a'), correct: false);
    expect(service.wrongCountFor('a'), 2);
    expect(service.seenCountFor('a'), 2);

    await service.recordAnswer(word('a'), correct: true);
    expect(service.wrongCountFor('a'), 1);

    await service.recordAnswer(word('a'), correct: true);
    expect(service.wrongCountFor('a'), 0);
    expect(service.weakWordCount, 0);
    expect(service.seenCountFor('a'), 4);

    // 더 맞혀도 0 밑으로 내려가지 않는다.
    await service.recordAnswer(word('a'), correct: true);
    expect(service.wrongCountFor('a'), 0);
  });

  test('많이 틀린 단어부터 정렬된다', () async {
    final WordProgressService service = WordProgressService.instance;
    await service.recordAnswer(word('b'), correct: false);
    await service.recordAnswer(word('c'), correct: false);
    await service.recordAnswer(word('c'), correct: false);
    expect(service.mostMissedIds, <String>['c', 'b']);
    expect(service.totalWrong, 3);
  });

  test('기록은 기기에 저장된다', () async {
    final WordProgressService service = WordProgressService.instance;
    await service.recordAnswer(word('d'), correct: false);
    await service.recordAnswer(word('d'), correct: false);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ww.wordProgress'), contains('"d":2'));
  });

  test('기록 지우기', () async {
    final WordProgressService service = WordProgressService.instance;
    await service.recordAnswer(word('e'), correct: false);
    await service.reset();
    expect(service.weakWordCount, 0);
    expect(service.totalWrong, 0);
    expect(service.seenCountFor('e'), 0);
  });
}
