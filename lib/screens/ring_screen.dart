import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/session_builder.dart';
import '../data/word_repository.dart';
import '../models/word.dart';
import '../services/alarm_service.dart';
import '../services/ringtone_service.dart';
import '../services/settings_service.dart';
import '../services/word_progress_service.dart';
import '../widgets/emergency_dismiss_button.dart';
import 'alarm_intro_view.dart';
import 'quiz_view.dart';
import 'study_view.dart';
import 'wake_up_view.dart';

enum RingSource { alarm, preview }

enum _Phase { loading, intro, study, quiz, cleared, error }

class RingScreen extends StatefulWidget {
  const RingScreen({
    super.key,
    required this.settings,
    required this.alarmService,
    required this.source,
    this.onClosed,
  });

  final SettingsService settings;
  final AlarmService alarmService;
  final RingSource source;
  final VoidCallback? onClosed;

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> with WidgetsBindingObserver {
  late final DateTime _startedAt;
  _Phase _phase = _Phase.loading;
  SessionPlan? _session;
  String _errorMessage = '';
  int _correctCount = 0;
  DateTime? _clearedAt;

  bool get _isPreview => widget.source == RingSource.preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAt = DateTime.now();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await WordRepository.instance.load();
      await WordProgressService.instance.load();
      final List<Word> levelWords =
          WordRepository.instance.byLevel(widget.settings.level);
      if (levelWords.length < 4) {
        if (!mounted) {
          return;
        }
        setState(() {
          _phase = _Phase.error;
          _errorMessage = '${widget.settings.level.label} 단어를 불러오지 못했어요.\nassets/words.json을 확인해 주세요.';
        });
        return;
      }
      final SessionPlan session = SessionBuilder.build(
        plan: widget.settings.plan,
        levelWords: levelWords,
        now: _startedAt,
        wrongCounts: WordProgressService.instance.wrongCounts,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _phase = _Phase.intro;
      });

      // 알람 발생: 소리 + 진동을 함께 켠다.
      await RingtoneService.instance.start();
      // iOS는 앱이 잠금 화면에서 계속 울릴 수 없으므로 30초 간격 연속 알림을 건다.
      if (!_isPreview) {
        await widget.alarmService.startIosAlarmChain();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _Phase.error;
        _errorMessage = '알람을 준비하지 못했어요.\n$error';
      });
    }
  }

  /// 첫 화면 3초가 지나 사용자가 시작 버튼을 누를 때.
  /// 소리는 끄고 진동만 남긴 뒤 학습/시험으로 넘어간다.
  Future<void> _beginSession() async {
    await RingtoneService.instance.muteSound();
    await widget.alarmService.stopRingingNotification(widget.settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = (_session?.hasStudy ?? false) ? _Phase.study : _Phase.quiz;
    });
  }

  void _onStudyFinished() {
    if (!mounted) {
      return;
    }
    setState(() => _phase = _Phase.quiz);
  }

  void _onQuizCleared(int correct) {
    if (!mounted) {
      return;
    }
    // 퀴즈를 통과하면 해지 버튼이 활성화된다. 진동은 해지할 때까지 계속된다.
    setState(() {
      _correctCount = correct;
      _clearedAt = DateTime.now();
      _phase = _Phase.cleared;
    });
  }

  /// 해지(또는 미리보기 닫기): 소리와 진동을 모두 멈춘다.
  Future<void> _dismiss() async {
    await RingtoneService.instance.stop();
    await widget.alarmService.cancelIosAlarmChain();
    if (!_isPreview) {
      // 울리고 있는 알림도 내리고, 그 요일의 다음 주 알람은 다시 예약한다.
      await widget.alarmService.stopRingingNotification(widget.settings);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPreview) {
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // 퀴즈를 통과하기 전에 앱을 벗어나면 5초 뒤 다시 울린다(iOS).
      final bool inSession = _phase == _Phase.intro ||
          _phase == _Phase.study ||
          _phase == _Phase.quiz;
      if (inSession) {
        widget.alarmService.scheduleIosBypassAlert();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 앱으로 돌아왔으니 연속 알림은 더 필요 없다.
      widget.alarmService.cancelIosAlarmChain();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RingtoneService.instance.stop();
    widget.onClosed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showEmergencyButton =
        !_isPreview && (_phase == _Phase.intro || _phase == _Phase.study || _phase == _Phase.quiz);
    final bool showPreviewClose = _isPreview && _phase != _Phase.cleared;

    return PopScope(
      canPop: _phase == _Phase.cleared || _isPreview,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildPhase(context)),
            if (showEmergencyButton)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: EmergencyDismissButton(onTriggered: _dismiss),
                ),
              ),
            if (showPreviewClose)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: IconButton(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.mutedText,
                    tooltip: '미리보기 닫기',
                  ),
                ),
              ),
            if (_isPreview && _phase != _Phase.cleared)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '미리보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    final SessionPlan? session = _session;

    switch (_phase) {
      case _Phase.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('알람을 준비하고 있어요', style: AppTextStyles.body),
            ],
          ),
        );
      case _Phase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    size: 40, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _dismiss,
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      case _Phase.intro:
        if (session == null) {
          return const SizedBox.shrink();
        }
        return AlarmIntroView(
          now: _startedAt,
          title: session.title,
          subtitle: session.subtitle,
          buttonLabel: session.hasStudy ? '단어 공부 시작' : '시험 시작',
          onStart: _beginSession,
        );
      case _Phase.study:
        if (session == null) {
          return const SizedBox.shrink();
        }
        return StudyView(
          words: session.studyWords,
          secondsPerWord: widget.settings.studySeconds,
          onFinished: _onStudyFinished,
        );
      case _Phase.quiz:
        if (session == null) {
          return const SizedBox.shrink();
        }
        return QuizView(
          pool: session.quizPool,
          target: session.quizTarget,
          wrongCounts: WordProgressService.instance.wrongCounts,
          onAnswered: (Word word, bool correct) {
            WordProgressService.instance.recordAnswer(word, correct: correct);
          },
          onFinished: _onQuizCleared,
        );
      case _Phase.cleared:
        return WakeUpView(
          studyCount: session?.studyCount ?? 0,
          correctCount: _correctCount,
          targetCount: session?.quizTarget ?? 0,
          clearedAt: _clearedAt ?? DateTime.now(),
          isPreview: _isPreview,
          onDismiss: _dismiss,
        );
    }
  }
}
