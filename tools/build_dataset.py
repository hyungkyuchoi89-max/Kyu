"""public 데이터에서 단어 DB(tools/word_data/*.json)를 만든다.

입력
- data_sources/dasi_words.jsonl : 표제어·품사·IPA·한국어 뜻·영어 예문(+한국어 번역)·레벨·트랙
  (studiojin-dev/dasi-public, CC BY-SA 4.0)
- tools/word_data_curated/*.json : 직접 작성한 보충 단어(기존 100단어 + 추가분)

카테고리 배분(카테고리 사이 단어 중복 0)
1) elementary  : elementary 트랙
2) middle      : middle 트랙
3) toeic       : toeic 트랙 (TSL/BSL 표제어 우선)
4) toefl       : toefl 트랙 (NAWL 표제어 우선)
5) high_suneung: csat 트랙 (남은 단어)

실행: python3 tools/build_dataset.py
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, '..', 'data_sources', 'dasi_words.jsonl')
SOURCE = os.path.abspath(SOURCE)
CURATED_DIR = os.path.join(ROOT, 'tools', 'word_data_curated')
OUT_DIR = os.path.join(ROOT, 'tools', 'word_data')

# (category, quota, 트랙, 우선 태그)
PLAN = [
    ('elementary', 950, 'elementary', set()),
    ('middle', 1500, 'middle', set()),
    ('toeic', 1500, 'toeic', {'tsl', 'bsl'}),
    ('toefl', 1550, 'toefl', {'nawl'}),
    ('high_suneung', 2000, 'csat', set()),
]

SKIP_POS = {'determiner', 'conjunction', 'pronoun', 'preposition', 'interjection'}
ABBREVIATIONS = {
    'dna', 'gps', 'ceo', 'dvd', 'ufo', 'pc', 'iq', 'gpa', 'tv', 'cd', 'ad', 'ex',
    'pa', 'pi', 'ow', 'ah', 'oh', 'hi', 'id', 'pm', 'am', 'mr', 'mrs', 'ms', 'dr',
    'st', 'vs', 'etc', 'usa', 'uk', 'ok', 'mph', 'km', 'kg', 'ft', 'lb',
}
# 알람 앱에 어울리지 않는 소재의 단어는 넣지 않는다.
SKIP_WORDS = {'suicide', 'rape', 'porn', 'naked'}
LEVEL_BY_CATEGORY = {'elementary': 2, 'middle': 3, 'high_suneung': 4, 'toeic': 4, 'toefl': 5}
USED_EXAMPLES = set()
# 공개 예문 중 알람 앱에 쓰기 어려운 문장은 직접 쓴 예문으로 바꾼다.
EXAMPLE_OVERRIDES = {
    'kill': 'The frost killed the young plants overnight.',
    'murder': 'The detective read the murder case file again.',
}


def clean_ipa(raw):
    if not raw:
        return None
    text = str(raw).strip()
    for sep in (';', ',', ' or '):
        if sep in text:
            text = text.split(sep)[0]
    text = text.replace('/', '').strip()
    text = re.sub(r'\s+', ' ', text)
    if not text or not re.search(r'[a-zæɑɒɔəɜɛɪʊʌʃʒθðŋɚɝɹˈˌː]', text):
        return None
    return f'/{text}/'


def word_forms(word):
    forms = {word, word + 's', word + 'es', word + 'ed', word + 'd', word + 'ing',
             word + 'er', word + 'est', word + 'ly'}
    if word.endswith('e'):
        forms.add(word[:-1] + 'ing')
        forms.add(word[:-1] + 'ed')
    if word.endswith('y'):
        forms.add(word[:-1] + 'ies')
        forms.add(word[:-1] + 'ied')
    if len(word) > 3 and word[-1] not in 'aeiou' and word[-2] in 'aeiou':
        forms.add(word + word[-1] + 'ing')
        forms.add(word + word[-1] + 'ed')
    return forms


def contains_word(sentence, word):
    pattern = r'(?<![A-Za-z])(' + '|'.join(
        re.escape(form) for form in sorted(word_forms(word), key=len, reverse=True)
    ) + r')(?![A-Za-z])'
    return re.search(pattern, sentence, re.IGNORECASE) is not None


def is_clean_sentence(sentence):
    text = sentence.strip()
    if not text:
        return False
    if not text.endswith(('.', '!', '?')):
        return False
    if len(text) > 105:
        return False
    words = re.findall(r"[A-Za-z][A-Za-z'\-]*", text)
    if not (4 <= len(words) <= 16):
        return False
    if re.search(r'[가-힣]', text):
        return False
    if re.search(r'https?://|@|\d{4,}', text):
        return False
    return True


SENSITIVE = re.compile(
    r'\b(kill(ed|ing|s)?|murder(ed|er|ers)?|suicide|rape|raped|sex|porn|drunk|'
    r'naked|nude|stupid|idiot|damn|shit|fuck|hell|affair)\b',
    re.IGNORECASE,
)


def pick_example(word, senses):
    candidates = []
    for sense in senses:
        for example in sense.get('examples') or []:
            target = (example.get('target') or '').strip()
            if not target or not contains_word(target, word):
                continue
            if not is_clean_sentence(target):
                continue
            count = len(re.findall(r"[A-Za-z][A-Za-z'\-]*", target))
            sensitive = 1 if SENSITIVE.search(target) else 0
            candidates.append((sensitive, abs(count - 9), len(target), target))
    if not candidates:
        # 완화: 길이 조건을 조금 풀어서 다시 찾는다
        for sense in senses:
            for example in sense.get('examples') or []:
                target = (example.get('target') or '').strip()
                if target and contains_word(target, word) and target.endswith(('.', '!', '?')) \
                        and len(target) <= 130 and not re.search(r'[가-힣]', target):
                    sensitive = 1 if SENSITIVE.search(target) else 0
                    candidates.append((sensitive, 9, len(target), target))
    if not candidates:
        return None
    candidates.sort()
    for candidate in candidates:
        if candidate[3] not in USED_EXAMPLES:
            return candidate[3]
    return candidates[0][3]


def clean_meaning(senses):
    meanings = []
    for sense in senses:
        for gloss in sense.get('gloss') or []:
            text = re.sub(r'\s+', ' ', str(gloss)).strip(' .,;')
            text = re.sub(r'^[A-Za-z][A-Za-z \-]{0,30}:\s*', '', text)
            text = re.sub(r'\s+', ' ', text).strip(' .,;')
            if not text or not re.search(r'[가-힣]', text):
                continue
            if text in meanings:
                continue
            meanings.append(text)
    if not meanings:
        return None
    return ', '.join(meanings[:3])


def eligible(entry):
    word = entry['headword'].strip()
    if len(word) < 2 or len(word) > 20:
        return False
    if word.lower() in ABBREVIATIONS or word.lower() in SKIP_WORDS:
        return False
    if entry['pos'] in SKIP_POS:
        return False
    if not re.fullmatch(r"[A-Za-z][A-Za-z'\-]*", word):
        return False
    if not clean_ipa(entry.get('ipa')):
        return False
    if not clean_meaning(entry['senses']):
        return False
    if pick_example(word, entry['senses']) is None:
        return False
    return True


def load_source():
    with open(SOURCE, 'r', encoding='utf-8') as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    by_word = {}
    for row in rows:
        key = row['headword'].strip().lower()
        if key in by_word:
            continue
        by_word[key] = row
    return by_word


def to_entry(row, category):
    word = row['headword'].strip()
    entry = {
        'word': word,
        'phonetic': clean_ipa(row.get('ipa')),
        'meaning': clean_meaning(row['senses']),
        'example': EXAMPLE_OVERRIDES.get(word.lower()) or pick_example(word, row['senses']),
        'level': int(row.get('level') or 4),
        'tags': set(row.get('tags') or []),
        'tracks': set(row.get('tracks') or []),
        'category': category,
    }
    USED_EXAMPLES.add(entry['example'])
    return entry


def select(by_word):
    used = set()
    chosen = {}
    for category, quota, track, priority_tags in PLAN:
        pool = [
            row for key, row in by_word.items()
            if key not in used and track in (row.get('tracks') or []) and eligible(row)
        ]
        priority = [row for row in pool if priority_tags & set(row.get('tags') or [])]
        rest = [row for row in pool if not (priority_tags & set(row.get('tags') or []))]
        key = lambda row: (int(row.get('level') or 4), row['headword'].lower())
        priority.sort(key=key)
        rest.sort(key=key)
        ordered = priority + rest
        picked = [to_entry(row, category) for row in ordered[:quota]]
        if len(picked) < quota:
            print(f'  ! {category}: {len(picked)}개만 확보 (목표 {quota})')
        for entry in picked:
            used.add(entry['word'].lower())
        chosen[category] = picked
    return chosen, used


def load_curated():
    curated = {}
    for category in [plan[0] for plan in PLAN]:
        path = os.path.join(CURATED_DIR, f'{category}.json')
        entries = []
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as handle:
                entries = json.load(handle)
        curated[category] = entries
    return curated


def main():
    if not os.path.exists(SOURCE):
        print(f'FAIL: 원본 데이터가 없습니다 - {SOURCE}')
        return 1

    print('원본 읽는 중...')
    by_word = load_source()
    print(f'  표제어 {len(by_word)}개')

    chosen, used = select(by_word)
    curated = load_curated()

    for category in chosen:
        extra = []
        for entry in curated.get(category, []):
            word = entry['word'].strip()
            if word.lower() in used:
                continue
            if not entry.get('phonetic', '').startswith('/'):
                continue
            used.add(word.lower())
            extra.append({
                'word': word,
                'phonetic': entry['phonetic'],
                'meaning': entry['meaning'],
                'example': entry['example'],
                'level': LEVEL_BY_CATEGORY[category],
                'tags': set(),
                'tracks': set(),
                'category': category,
            })
        chosen[category].extend(extra)
        chosen[category].sort(key=lambda e: (e['level'], e['word'].lower()))

    total = 0
    os.makedirs(OUT_DIR, exist_ok=True)
    for category, entries in chosen.items():
        payload = [
            {
                'word': e['word'],
                'phonetic': e['phonetic'],
                'meaning': e['meaning'],
                'example': e['example'],
            }
            for e in entries
        ]
        with open(os.path.join(OUT_DIR, f'{category}.json'), 'w', encoding='utf-8') as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
        total += len(payload)
        print(f'  {category:<13} {len(payload):>5}개')

    print(f'  합계 {total}개')
    return 0


if __name__ == '__main__':
    sys.exit(main())
