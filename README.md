# WordWake — 영어단어 알람 앱

알람이 울리면 영어단어를 학습하고 2지선다 퀴즈를 통과해야 알람이 꺼지는
Flutter 앱입니다. Android와 iOS를 함께 지원합니다.

- **이지 플랜 (월~금)** · **스파르타 플랜 (월~일)**
- 단어 레벨 5종: 초등영어 960 · 중등영어 1,505 · 고등수능영어 2,002 · 토익단어 1,501 · 토플단어 1,563 (총 **7,531단어**)
- 학습 화면 1~5초 자동 넘김, 2지선다 퀴즈, 매달 마지막 주 월간 복습
- 단어 풀을 끝까지 돌면 자동으로 처음에 이어 붙여 **끊임없이 순환**하고,
  틀린 단어는 `wrongCount`로 기록해 다음 순환·복습에서 먼저 다시 냅니다.

---

## 1. 플랜별 알람 규칙

| 플랜 | 요일 | 알람 후 진행 | 알람이 꺼지는 조건 |
| --- | --- | --- | --- |
| 이지 | 월~목 | 새 단어 20개 학습 → 퀴즈 | 정답 **5개** |
| 이지 | 금 | 바로 퀴즈 (이번 주 월~목 80단어) | 정답 **10개** |
| 이지 | 토·일 | 알람 없음 | — |
| 스파르타 | 월~금 | 새 단어 20개 학습 → 퀴즈 (주 100단어) | 정답 **5개** |
| 스파르타 | 토·일 | 바로 퀴즈 (이번 주 100단어) | 정답 **20개** |

### 매달 마지막 주 월간 복습

- **이지 플랜**: 그 달의 **마지막 금요일**은 이번 주 80단어 대신,
  **그 달에 배운 단어 전체**(월간 누적 풀)에서 10문제를 냅니다.
- **스파르타 플랜**: 그 달의 **마지막 토·일요일**은 이번 주 100단어 대신,
  **그 달에 배운 단어 전체**에서 20문제를 냅니다.

판정 규칙은 `SessionBuilder.isLastWeekOfMonth()`입니다.
"같은 요일이 다음 주로 넘어가면 그 달의 마지막 그 요일"로 판단합니다.

```dart
// 2026-11-27(금) + 7일 = 2026-12-04 → 11월의 마지막 금요일
static bool isLastWeekOfMonth(DateTime date) {
  final next = DateTime(date.year, date.month, date.day)
      .add(const Duration(days: 7));
  return next.month != date.month;
}
```

월간 누적 풀은 `SessionBuilder.monthPool()`이 그 달 1일부터 어제까지의
평일(월~금) 배정 단어를 그대로 이어 붙여 만듭니다. 주 단위 회전 때문에
한 주에 100개를 모두 보므로, 월간 풀에는 같은 단어가 여러 번 들어갑니다
(그 달에 실제로 본 단어를 그대로 모으는 방식).

### 단어 배정 방식

- 하루 20개, 월~금 5일이면 **그 주에 배정된 100개**를 모두 채웁니다.
- 시작 위치가 **매주 20칸씩 밀려서** 같은 요일이라도 주마다 다른 단어를 만납니다.
- 한 주 안에서 월~금의 20개 블록은 서로 겹치지 않습니다.
- 단어 풀(예: 초등 960개)을 한 바퀴 다 돌면 마지막 단어 다음에 첫 단어가
  이어 붙습니다. 단어가 떨어져서 알람이 멈추는 일은 없습니다.

### 오답 가중 순환 (틀린 단어는 계속 다시)

- 퀴즈에서 틀린 단어는 `wrongCount`가 1 올라가고, 맞히면 1 내려갑니다(0에서 멈춤).
  기록은 `SharedPreferences`(`ww.wordProgress`)에 단어 id별로 저장됩니다.
  (`lib/services/word_progress_service.dart`)
- **같은 세션 안에서**: 퀴즈 엔진이 풀을 다시 섞을 때 `wrongCount`가 높은 단어를
  앞쪽에 배치합니다. 방금 틀린 단어가 다음 바퀴에서 먼저 다시 나옵니다.
- **한 바퀴를 돈 뒤**: `SessionBuilder`가 `wrongCount` 순으로 풀을 다시 정렬해,
  많이 틀린 단어부터 새 순환을 시작합니다.
- **주간·월간 복습**: 복습 풀에서도 퀴즈 엔진이 `wrongCount` 순으로 문제를 냅니다.
- 홈 화면의 **반복 학습** 카드에서 틀린 단어 수·누적 오답 횟수를 보고 기록을 지울 수 있습니다.

```dart
// lib/data/session_builder.dart
static int cycleIndex(List<Word> pool, DateTime date) =>
    (weekIndex(date) * wordsPerDay) ~/ pool.length;   // 몇 바퀴째인지

static List<Word> priorityOrder(List<Word> pool, Map<String, int> wrongCounts) {
  // wrongCount 내림차순, 같으면 원래(쉬운 단어 → 어려운 단어) 순서
}
```

---

## 2. 알람 화면 흐름 (소리 / 진동 상태)

| 단계 | 화면 | 소리 | 진동 |
| --- | --- | --- | --- |
| 1 | 알람 첫 화면 (3초 대기) | 🔔 켜짐 | 📳 켜짐 |
| 2 | 단어 학습 20개 (`단어 공부 시작` 후) | 🔇 꺼짐 | 📳 켜짐 |
| 3 | 퀴즈 (목표 정답까지) | 🔇 꺼짐 | 📳 켜짐 |
| 4 | 퀴즈 통과 → **해지 버튼 활성화** | 🔇 꺼짐 | 📳 켜짐 |
| 5 | `알람 해지` 누름 | 🔇 꺼짐 | ⏹ 정지 |

- 첫 화면은 **정확히 3초** 동안 소리와 진동이 함께 울리고, 그 뒤에야
  `단어 공부 시작`(학습이 있는 날) 또는 `시험 시작`(퀴즈만 있는 날) 버튼이 활성화됩니다.
  원형 게이지에 남은 시간이 표시됩니다.
- 시작 버튼을 누르면 **소리만 끄고 진동은 유지**합니다.
  (`RingtoneService.muteSound()`)
- 퀴즈 목표를 채우면 해지 버튼이 켜지고, 누르는 순간 진동까지 멈춥니다.
  (`RingtoneService.stop()`)
- 퀴즈는 풀을 다 써도 다시 섞여서 목표 정답 수에 닿을 때까지 계속 나옵니다.

### 비상 종료 버튼

- 위치: 알람·학습·퀴즈 화면 **왼쪽 위 모서리**
- 알람을 정상적으로 끄려면 퀴즈를 통과해야 하지만, 급한 상황을 위해
  **10초 동안 계속 누르고 있으면** 알람이 꺼집니다.
- 누르는 동안 원형 게이지와 남은 초(`7s` 등)가 표시되고, 손을 떼면 처음부터 다시 셉니다.

---

## 3. 단어 데이터

`assets/words.json` — 5개 카테고리 · 총 **7,531단어** (카테고리 안/사이 중복 0)

```json
{
  "version": 1,
  "count": 7531,
  "categories": {
    "elementary": { "label": "초등영어", "count": 960 }
  },
  "words": [
    {
      "id": "elementary-0001",
      "category": "elementary",
      "word": "apple",
      "phonetic": "/ˈæp.əl/",
      "meaning": "사과",
      "example": "I eat an apple every morning."
    }
  ]
}
```

| category | 화면 표시 | 단어 수 | 목표 범위 |
| --- | --- | --- | --- |
| `elementary` | 초등영어 | 960 | 800+ (교육부 초등 기본 어휘 범위) |
| `middle` | 중등영어 | 1,505 | 1,200~1,500+ (중등 핵심 어휘) |
| `high_suneung` | 고등수능영어 | 2,002 | 1,800~2,000+ (수능 필수 어휘) |
| `toeic` | 토익단어 | 1,501 | 1,500+ (TSL/BSL 비즈니스 어휘) |
| `toefl` | 토플단어 | 1,563 | 1,500+ (NAWL 학술 어휘) |
| **합계** | | **7,531** | 6,000~8,000+ |

모든 항목은 `word`(영어 표제어) · `phonetic`(IPA `/.../`) · `meaning`(한국어 뜻) ·
`example`(영어 예문, 해당 단어 포함)을 가지고 있고, 카테고리 사이에도 같은
영어 단어가 한 번만 들어갑니다.

### 데이터 출처 · 라이선스

| 자료 | 내용 | 라이선스 |
| --- | --- | --- |
| [studiojin-dev/dasi-public](https://github.com/studiojin-dev/dasi-public) `en-ko-core` | 표제어·품사·IPA·한국어 뜻·예문·CEFR/시험 트랙 (Tatoeba, 한국어 위키낱말사전, NGSL/TSL/BSL/NAWL 기반) | CC BY-SA 4.0 |
| Tatoeba 문장 | 영어 예문 원문 | CC BY 2.0 FR |
| 직접 작성 | 기존 100단어와 보충 단어(초등 500, 중등 300 등)의 뜻·예문 | 이 프로젝트 |

> 데이터는 CC BY-SA 4.0(저작자표시-동일조건변경허락)을 따릅니다.
> 앱 코드는 별도이며, 데이터를 다시 배포할 때는 같은 라이선스와 위 출처 표기가 필요합니다.

### 검증 · 재생성

```bash
# 무결성 검증 (JSON 문법, 카테고리별 최소 개수, 카테고리 안/사이 중복,
# 필수 필드, IPA 형식, 뜻의 한글 포함 여부)
python3 tools/verify_words.py

# 예문에 해당 단어(활용형 포함)가 실제로 들어 있는지까지 오류로 검사
python3 tools/verify_words.py --strict-example

# tools/word_data/*.json 조각을 합쳐 assets/words.json 재생성 (id·category 부여)
python3 tools/build_words.py

# 공개 데이터에서 tools/word_data/*.json 다시 만들기 (data_sources/ 필요)
python3 tools/build_dataset.py
```

`tools/word_data/`에는 카테고리별 원본 조각이 있고, `build_words.py`가
`id`(`카테고리-0001`, 4자리)와 `category`를 붙여 `assets/words.json`을 만듭니다.
`tools/word_data_curated/`는 처음에 직접 작성한 단어(기존 100단어 + 보충분)이고,
`build_dataset.py`가 공개 데이터와 합칠 때 중복을 걸러 냅니다.

---

## 4. 프로젝트 구조

```
word_alarm_app/
├── pubspec.yaml
├── analysis_options.yaml
├── assets/
│   ├── words.json                  # 7,531단어 DB
│   └── audio/alarm.wav             # 알람 음원(기기 기본음이 없을 때/iOS용)
├── lib/
│   ├── main.dart                   # 앱 시작, 설정 로드, 알람 재예약
│   ├── app.dart                    # MaterialApp, 알림 탭 → 알람 화면 연결
│   ├── core/theme.dart             # 색상·타이포그래피
│   ├── models/
│   │   ├── word.dart               # 단어 모델
│   │   ├── word_level.dart         # 5개 레벨
│   │   ├── study_plan.dart         # 이지/스파르타 플랜 규칙
│   │   └── day_alarm.dart          # 요일별 알람 설정
│   ├── data/
│   │   ├── word_repository.dart    # words.json 로드/레벨별 조회
│   │   ├── session_builder.dart    # 요일·플랜·월간 복습 풀, 오답 가중 순환
│   │   └── quiz_engine.dart        # 2지선다 문제 생성(오답 단어 우선)
│   ├── services/
│   │   ├── settings_service.dart   # 플랜·레벨·속도·요일 알람 저장
│   │   ├── word_progress_service.dart  # 단어별 wrongCount 저장(반복 학습)
│   │   ├── alarm_service.dart      # 요일 반복 알람 예약(iOS 연속 알림 포함)
│   │   └── ringtone_service.dart   # 소리/진동 분리 제어
│   ├── screens/
│   │   ├── home_screen.dart        # 플랜·레벨·속도·요일 알람 설정
│   │   ├── ring_screen.dart        # 알람 상태 머신(첫 화면→학습→퀴즈→해지)
│   │   ├── alarm_intro_view.dart   # 3초 대기 화면
│   │   ├── study_view.dart         # 단어 학습(1~5초 자동 넘김)
│   │   ├── quiz_view.dart          # 2지선다 퀴즈(오답 시 빨간 배경 0.5초)
│   │   └── wake_up_view.dart       # 통과 화면 + 해지 버튼
│   └── widgets/
│       └── emergency_dismiss_button.dart  # 10초 길게 누르기 비상 종료
├── test/
│   ├── session_builder_test.dart   # 플랜·월간 복습·퀴즈 엔진·오답 가중 순환 테스트
│   └── word_progress_service_test.dart  # wrongCount 저장/감소 테스트
├── tools/
│   ├── build_words.py
│   ├── build_dataset.py            # 공개 데이터 → tools/word_data/*.json
│   ├── verify_words.py
│   ├── make_icons.py               # 런처 아이콘 PNG 생성
│   ├── make_alarm_sound.py         # alarm.wav 생성
│   ├── word_data/*.json            # 카테고리별 단어 원본(최종)
│   └── word_data_curated/*.json    # 직접 작성한 보충 단어
├── android/                        # 전체 Android 빌드 설정 + 권한
└── ios/Runner/                     # Info.plist, AppDelegate.swift, entitlements
```

### 실행 로직 요약

1. `main.dart`가 설정을 읽고 켜져 있는 요일 알람을 다시 예약합니다.
2. 알람 시각이 되면 로컬 알림이 울립니다(Android는 전체 화면 인텐트).
3. 알림을 누르면 `RingScreen`이 열리고 `SessionBuilder.build()`가
   오늘의 학습/퀴즈 계획을 만듭니다.
4. 3초 첫 화면 → 학습(있으면) → 퀴즈 → 통과 → 해지.
5. 해지하면 남은 소리·진동을 모두 멈추고 홈으로 돌아갑니다.

---

## 5. 로컬 빌드

### 준비물

- Flutter **3.24.5** (stable) 이상
- Java **17**
- Android SDK (compileSdk는 Flutter 기본값 사용)
- iOS 빌드: macOS + Xcode

### Android APK

```bash
cd word_alarm_app
flutter pub get
flutter test                 # 플랜/월간 복습/퀴즈 테스트
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

### 앱 실행

```bash
flutter devices
flutter run
```

### iOS

이 저장소에는 `ios/Runner`의 핵심 설정 파일(`Info.plist`, `AppDelegate.swift`,
`Runner.entitlements`)이 들어 있습니다. Xcode 프로젝트 파일(`Runner.xcodeproj`)은
포함되어 있지 않으므로, Mac에서 아래처럼 플랫폼 파일을 생성한 뒤
`ios/Runner`의 설정이 유지되었는지 확인하세요.

```bash
flutter create --platforms=ios .
cd ios && pod install && cd ..
flutter run -d ios
```

Xcode의 **Runner > Signing & Capabilities**에서
**Push Notifications / Time Sensitive Notifications**를 켜면
`Runner.entitlements`의 `com.apple.developer.usernotifications.time-sensitive`가 적용됩니다.

---

## 6. GitHub Actions로 APK 자동 빌드

`.github/workflows/build_apk.yml`에 워크플로가 들어 있습니다.

1. 이 폴더를 GitHub 저장소에 올립니다. (`main` 또는 `master` 브랜치)
2. GitHub → **Actions** → **Build Android APK** → **Run workflow**로 수동 실행하거나,
   브랜치에 push하면 자동으로 실행됩니다.
3. 빌드가 끝나면 **Artifacts**에서 `wordwake-release-apk`를 내려받습니다.
   (내부에 `app-release.apk`)

워크플로가 하는 일:

```yaml
- actions/setup-java@v4   (Temurin 17)
- subosito/flutter-action@v2  (Flutter 3.24.5, stable)
- flutter pub get
- flutter analyze || true
- flutter build apk --release
- actions/upload-artifact@v4
```

> 릴리스 APK는 편의를 위해 **debug 키로 서명**되어 있습니다(`android/app/build.gradle`).
> 스토어 배포 전에는 `key.properties`와 `signingConfigs.release`를 설정하세요.

---

## 7. Android vs iOS 알람 동작 차이

Apple은 잠금 화면/백그라운드에서 앱이 소리를 계속 재생하는 것을 허용하지 않습니다.
그래서 두 플랫폼의 구현이 다릅니다.

### Android

- `flutter_local_notifications`의 **exact alarm**(`AndroidScheduleMode.exactAllowWhileIdle`)과
  요일 반복(`DateTimeComponents.dayOfWeekAndTime`)으로 예약합니다.
- 알림 채널 소리는 앱 번들의 `res/raw/alarm.wav`이고, `fullScreenIntent`로
  잠금 화면 위에 앱 화면을 띄웁니다. (`FLAG_INSISTENT`로 소리 반복)
- 앱이 열리면 네이티브 채널(`wordwake/ringtone`)이
  `RingtoneManager.getDefaultUri(TYPE_ALARM)`로 **기기 기본 알람음**을
  알람 볼륨/알람 용도로 무한 반복 재생합니다. (기기 기본음이 없으면 `alarm.wav` 사용)
- 필요한 권한: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
  `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`, `VIBRATE`,
  `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`
- 알람 화면은 `showWhenLocked` / `turnScreenOn`으로 잠금 화면에서도 켜집니다.

### iOS (알람 우회 방지 워크어라운드)

- `Info.plist`에 `UIBackgroundModes` = `audio`, `fetch`, `remote-notification`을 켜고,
  알림은 **Time-Sensitive interruption level**로 보냅니다.
- 알람이 울린 뒤 앱이 잠금 화면에서 계속 소리내지 못하는 제약을 보완하기 위해,
  `AlarmService.startIosAlarmChain()`이 **30초 간격으로 최대 10개의 연속 알림**을
  미리 예약합니다. 사용자가 알림을 눌러 앱에 들어오면
  `cancelIosAlarmChain()`이 남은 연속 알림을 **즉시 취소**합니다.
- 앱에 들어온 뒤에도 **퀴즈를 통과하기 전에 앱을 벗어나면**
  (`AppLifecycleState.paused` / `detached`) `scheduleIosBypassAlert()`가
  **5초 뒤 다시 울리는 알림**을 예약해 알람을 우회하지 못하게 합니다.
- 학습/퀴즈 중에는 소리를 끄고 진동만 유지하는 것은 Android와 동일합니다.
- 알림 소리는 iOS 기본 알림음(`sound: 'default'`)을 사용합니다.
  커스텀 알람음을 쓰려면 `alarm.wav`를 Xcode의 Runner 타깃에 리소스로 추가하고
  `DarwinNotificationDetails(sound: 'alarm.wav')`로 바꾸면 됩니다.
- iOS는 기기 기본 알람음을 코드로 재생할 수 없어, 앱 번들의 `alarm.wav`로 대체합니다.

---

## 8. 권한 안내 (사용자에게 보여 줄 내용)

- **알림**: 정해진 시각에 알람을 띄웁니다.
- **알람 및 리마인더(정확한 알람)**: 1분 늦지 않게 정확히 울립니다.
  Android 12+는 설정에서 직접 허용해야 할 수 있습니다.
- **전체 화면 알림**: 잠금 화면 위로 알람 화면을 띄웁니다.
- **배터리 최적화 제외**: 제조사 절전 정책으로 알람이 늦는 것을 줄입니다.
- **진동**: 학습/퀴즈 중 진동으로 알람 상태를 알립니다.

---

## 9. 자주 고치는 곳

| 바꾸고 싶은 것 | 파일 |
| --- | --- |
| 색상·글자 크기 | `lib/core/theme.dart` (딥네이비 `#121826`, 오프화이트 `#F8FAFC`, 웜옐로 `#FBBF24`) |
| 요일별 학습/퀴즈 개수, 월간 복습 | `lib/data/session_builder.dart` |
| 오답 시 빨간 배경(0.5초), 정답 목표 | `lib/screens/quiz_view.dart` |
| 학습 자동 넘김 시간 | 홈 화면 슬라이더 → `SettingsService.studySeconds` (1~5초) |
| 3초 첫 화면 대기 | `lib/screens/alarm_intro_view.dart`의 `waitDuration` |
| 비상 종료 10초 | `lib/widgets/emergency_dismiss_button.dart`의 `holdDuration` |
| iOS 연속 알림 간격/개수 | `lib/services/alarm_service.dart`의 `iosChainInterval`, `iosChainCount` |
| 단어 추가 | `tools/word_data/*.json` 수정 후 `python3 tools/build_words.py` |
| 오답 가중치·반복 순환 | `lib/services/word_progress_service.dart`, `SessionBuilder.priorityOrder` |

---

## 10. 검증 결과

- `python3 tools/verify_words.py --strict-example` → **통과**
  - 전체 7,531단어 (초등 960 / 중등 1,505 / 수능 2,002 / 토익 1,501 / 토플 1,563)
  - 카테고리 안 중복 0, **카테고리 사이 중복 0** (전체 고유 단어 7,531개)
  - 필수 필드·IPA `/.../` 형식·한국어 뜻·예문 속 단어 포함 모두 이상 없음
- `dart format --output=none lib test` → 문법 오류 없음 (23개 파일 파싱 확인)
- `flutter test` (기대) → 플랜 규칙, 월간 복습 풀, 주간 100단어 중복 없음,
  2지선다 생성, **풀 소진 후 무한 재순환**, **오답 단어 우선 출제**,
  `wrongCount` 증가/감소·저장 테스트

> 참고: 이 환경에는 Flutter SDK가 없어 `flutter test`/APK 빌드는 수행하지 못했습니다.
> Dart SDK로 소스 파싱만 확인했고, GitHub Actions 워크플로가 첫 push에서 APK를 만들어 줍니다.
