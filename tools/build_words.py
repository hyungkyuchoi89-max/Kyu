"""words.json 조각을 하나로 합친다.

`tools/word_data/<category>.json` 파일은 다음 형식의 배열이다.
    [{"word": "...", "phonetic": "/.../", "meaning": "...", "example": "..."}]

합치면서 id(예: elementary-001)와 category를 붙여
`assets/words.json`을 만든다.

실행: python3 tools/build_words.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, 'tools', 'word_data')
OUTPUT = os.path.join(ROOT, 'assets', 'words.json')

CATEGORIES = [
    ('elementary', '초등영어'),
    ('middle', '중등영어'),
    ('high_suneung', '고등수능영어'),
    ('toeic', '토익단어'),
    ('toefl', '토플단어'),
]


def main():
    words = []
    summary = {}
    for category, label in CATEGORIES:
        path = os.path.join(DATA_DIR, f'{category}.json')
        with open(path, 'r', encoding='utf-8') as handle:
            entries = json.load(handle)

        for index, entry in enumerate(entries, start=1):
            words.append({
                'id': f'{category}-{index:04d}',
                'category': category,
                'word': entry['word'].strip(),
                'phonetic': entry['phonetic'].strip(),
                'meaning': entry['meaning'].strip(),
                'example': entry['example'].strip(),
            })
        summary[category] = {'label': label, 'count': len(entries)}

    payload = {
        'version': 1,
        'count': len(words),
        'categories': summary,
        'words': words,
    }

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    print(f'wrote {OUTPUT} ({len(words)} words)')
    for category, info in summary.items():
        print(f'  {category}: {info["count"]}')


if __name__ == '__main__':
    main()
