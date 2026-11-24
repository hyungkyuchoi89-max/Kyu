"""assets/words.json 검증 스크립트.

확인 항목
1. 파일이 올바른 JSON이고 최상위 구조가 맞는지
2. count 값과 실제 단어 수가 같은지
3. 카테고리 5개가 각각 목표 개수 이상인지 (초등 800 / 중등 1,200 / 수능 1,800 / 토익 1,500 / 토플 1,500)
4. 카테고리 안에서 영어 단어가 중복되지 않는지
5. 카테고리 사이에서도 영어 단어가 중복되지 않는지 (완전히 다른 단어)
6. id가 유일하고 `카테고리-0000` 형식인지
7. 모든 필수 필드(id, category, word, phonetic, meaning, example)가 비어 있지 않은지
8. 발음기호가 /.../ 형태인지, 뜻에 한글이 있는지
9. 예문에 해당 단어(활용형 포함)가 들어 있는지

실행: python3 tools/verify_words.py [--strict-example]
종료 코드 0 = 통과, 1 = 실패
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS_PATH = os.path.join(ROOT, 'assets', 'words.json')

# 카테고리별 최소 단어 수 (이 이상이면 통과)
EXPECTED_CATEGORIES = ['elementary', 'middle', 'high_suneung', 'toeic', 'toefl']
MIN_WORDS_PER_CATEGORY = {
    'elementary': 800,
    'middle': 1200,
    'high_suneung': 1800,
    'toeic': 1500,
    'toefl': 1500,
}
MIN_TOTAL_WORDS = sum(MIN_WORDS_PER_CATEGORY.values())
REQUIRED_FIELDS = ['id', 'category', 'word', 'phonetic', 'meaning', 'example']


def word_forms(word):
    """예문에서 인정할 활용형 목록."""
    forms = {word, word + 's', word + 'es', word + 'ed', word + 'd', word + 'ing',
             word + 'er', word + 'est', word + 'ly'}
    if word.endswith('e'):
        forms.add(word[:-1] + 'ing')
        forms.add(word[:-1] + 'ed')
    if word.endswith('y'):
        forms.add(word[:-1] + 'ies')
        forms.add(word[:-1] + 'ied')
        forms.add(word[:-1] + 'ily')
    if len(word) > 3 and word[-1] not in 'aeiou' and word[-2] in 'aeiou':
        forms.add(word + word[-1] + 'ing')
        forms.add(word + word[-1] + 'ed')
        forms.add(word + word[-1] + 'er')
    return forms


def example_contains(word, example):
    pattern = r'(?<![A-Za-z])(' + '|'.join(
        re.escape(form) for form in sorted(word_forms(word.lower()), key=len, reverse=True)
    ) + r')(?![A-Za-z])'
    return re.search(pattern, example.lower()) is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--strict-example',
        action='store_true',
        help='예문에 해당 단어가 실제로 들어 있지 않으면 오류로 처리한다.',
    )
    args = parser.parse_args()

    errors = []
    warnings = []

    if not os.path.exists(WORDS_PATH):
        print(f'FAIL: {WORDS_PATH} 파일이 없습니다.')
        return 1

    with open(WORDS_PATH, 'r', encoding='utf-8') as handle:
        raw = handle.read()

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        print(f'FAIL: JSON 문법 오류 - {error}')
        return 1

    if not isinstance(payload, dict):
        print('FAIL: 최상위는 객체여야 합니다.')
        return 1

    words = payload.get('words')
    if not isinstance(words, list):
        print('FAIL: words 배열이 없습니다.')
        return 1

    if payload.get('count') != len(words):
        errors.append(f'count({payload.get("count")})가 실제 단어 수({len(words)})와 다릅니다.')
    if len(words) < MIN_TOTAL_WORDS:
        errors.append(f'전체 단어 수가 {len(words)}개입니다. 최소 {MIN_TOTAL_WORDS}개여야 합니다.')

    seen_ids = set()
    seen_words = {}
    by_category = {category: [] for category in EXPECTED_CATEGORIES}

    for index, entry in enumerate(words):
        where = f'{index + 1}번째 항목'
        if not isinstance(entry, dict):
            errors.append(f'{where}: 객체가 아닙니다.')
            continue

        for field in REQUIRED_FIELDS:
            value = entry.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f'{where}: {field} 값이 비어 있거나 문자열이 아닙니다.')

        category = entry.get('category')
        if category not in EXPECTED_CATEGORIES:
            errors.append(f'{where}: 알 수 없는 category "{category}"')
            continue
        by_category[category].append(entry)

        word_id = entry.get('id', '')
        if word_id in seen_ids:
            errors.append(f'{where}: id 중복 "{word_id}"')
        seen_ids.add(word_id)

        if not re.fullmatch(re.escape(category) + r'-\d{4}', str(word_id)):
            errors.append(f'{where}: id 형식이 잘못되었습니다 ("{word_id}")')

        word = str(entry.get('word', ''))
        key = word.strip().lower()
        if key in seen_words and seen_words[key] != category:
            errors.append(f'{where}: 카테고리 간 단어 중복 "{word}" ({seen_words[key]} ↔ {category})')
        elif key in seen_words:
            errors.append(f'{where}: 카테고리 내 단어 중복 "{word}"')
        else:
            seen_words[key] = category

        phonetic = str(entry.get('phonetic', ''))
        if not re.fullmatch(r'/.+/', phonetic):
            errors.append(f'{where}: 발음기호는 /.../ 형식이어야 합니다 ("{phonetic}")')

        meaning = str(entry.get('meaning', ''))
        if not re.search(r'[가-힣]', meaning):
            errors.append(f'{where}: 뜻에 한글이 없습니다 ("{meaning}")')

        if ' ' in word.strip():
            warnings.append(f'{where}: 단어에 공백이 있습니다 ("{word}")')
        if not re.fullmatch(r"[A-Za-z][A-Za-z'\-]*", word.strip()):
            warnings.append(f'{where}: 영어 단어가 아닌 문자가 있습니다 ("{word}")')

        example = str(entry.get('example', ''))
        if not example_contains(word.strip(), example):
            message = f'{where}: 예문에 "{word}"가 보이지 않습니다. ({example[:60]})'
            if args.strict_example:
                errors.append(message)
            else:
                warnings.append(message)

    for category in EXPECTED_CATEGORIES:
        entries = by_category[category]
        minimum = MIN_WORDS_PER_CATEGORY[category]
        if len(entries) < minimum:
            errors.append(
                f'{category}: {len(entries)}개입니다. 최소 {minimum}개여야 합니다.',
            )
        if len(entries) != len({str(e.get("word", "")).strip().lower() for e in entries}):
            errors.append(f'{category}: 고유 단어 수가 전체 항목 수와 다릅니다.')

    print('=== WordWake 단어 DB 검증 ===')
    print(f'파일: {os.path.relpath(WORDS_PATH, ROOT)}')
    print(f'전체 단어: {len(words)}개 (최소 기준 {MIN_TOTAL_WORDS}개)')
    for category in EXPECTED_CATEGORIES:
        entries = by_category[category]
        unique = len({str(e.get("word", "")).strip().lower() for e in entries})
        print(
            f'  - {category:<13} {len(entries):>5}개 (고유 {unique:>5}개, '
            f'최소 {MIN_WORDS_PER_CATEGORY[category]}개)'
        )
    print(f'  - 전체 고유 단어: {len(seen_words)}개')

    if warnings:
        print(f'\n경고 {len(warnings)}건:')
        for warning in warnings[:10]:
            print(f'  · {warning}')
        if len(warnings) > 10:
            print(f'  · ... 외 {len(warnings) - 10}건')

    if errors:
        print(f'\n실패: 오류 {len(errors)}건')
        for error in errors[:20]:
            print(f'  · {error}')
        if len(errors) > 20:
            print(f'  · ... 외 {len(errors) - 20}건')
        return 1

    print('\n통과: 5개 카테고리 · 카테고리별 최소 기준 충족 · 카테고리 안/사이 중복 없음')
    return 0


if __name__ == '__main__':
    sys.exit(main())
