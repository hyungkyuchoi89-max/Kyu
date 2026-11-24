import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/word_repository.dart';
import '../models/day_alarm.dart';
import '../models/study_plan.dart';
import '../models/word_level.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import '../services/word_progress_service.dart';
import 'ring_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.alarmService,
  });

  final SettingsService settings;
  final AlarmService alarmService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskForPermissions();
    });
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      await WordRepository.instance.load();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // 홈 화면은 단어 데이터 없이도 설정을 보여 줄 수 있다.
    }
  }

  Future<void> _maybeAskForPermissions() async {
    if (widget.settings.onboardingDone || !mounted) {
      return;
    }
    final bool? granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('알람을 위해 권한이 필요해요'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('· 알림 권한: 정해진 시각에 알람을 띄워요.'),
            SizedBox(height: 6),
            Text('· 알람 및 리마인더 권한: 1분 늦지 않게 정확히 울려요.'),
            SizedBox(height: 6),
            Text('· 배터리 최적화에서 제외하면 더 안정적으로 울려요.'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('권한 허용'),
          ),
        ],
      ),
    );
    if (granted == true) {
      await _ensurePermissions();
    }
    await widget.settings.markOnboardingDone();
  }

  Future<void> _ensurePermissions() async {
    await widget.alarmService.requestPermissions();
    await _reschedule(showSnack: true);
  }

  Future<void> _reschedule({bool showSnack = false}) async {
    if (!mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.alarmService.rescheduleAll(widget.settings);
      if (showSnack && mounted) {
        _showSnack(widget.settings.hasEnabledAlarm
            ? '알람을 다시 예약했어요.'
            : '알람이 모두 꺼져 있어요.');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('알람 예약에 실패했어요. 알림·알람 권한을 확인해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectPlan(StudyPlan plan) async {
    if (widget.settings.plan == plan) {
      return;
    }
    await widget.settings.setPlan(plan);
    await _reschedule(showSnack: true);
  }

  Future<void> _selectLevel(WordLevel level) async {
    await widget.settings.setLevel(level);
  }

  Future<void> _toggleDay(int weekday, bool enabled) async {
    await widget.settings.setAlarmEnabled(weekday, enabled);
    await _reschedule();
  }

  Future<void> _pickTime(int weekday) async {
    final DayAlarm alarm = widget.settings.alarmFor(weekday);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: alarm.time,
      helpText: '${alarm.label}요일 알람 시간',
      cancelText: '취소',
      confirmText: '정하기',
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) {
      return;
    }
    await widget.settings.setAlarmTime(weekday, picked.hour, picked.minute);
    if (!alarm.enabled) {
      await widget.settings.setAlarmEnabled(weekday, true);
    }
    await _reschedule(showSnack: true);
  }

  Future<void> _openPreview() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RingScreen(
          settings: widget.settings,
          alarmService: widget.alarmService,
          source: RingSource.preview,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.settings,
          builder: (BuildContext context, Widget? child) {
            return Stack(
              children: <Widget>[
                _buildBody(context),
                if (_busy)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: <Widget>[
        _buildHeader(),
        const SizedBox(height: 24),
        _buildNextAlarmCard(),
        const SizedBox(height: 28),
        const Text('플랜', style: AppTextStyles.section),
        const SizedBox(height: 10),
        _buildPlanCard(StudyPlan.easy),
        const SizedBox(height: 10),
        _buildPlanCard(StudyPlan.sparta),
        const SizedBox(height: 28),
        const Text('단어 레벨', style: AppTextStyles.section),
        const SizedBox(height: 10),
        _buildLevelChips(),
        const SizedBox(height: 16),
        _buildWordProgressCard(),
        const SizedBox(height: 28),
        const Text('학습 속도', style: AppTextStyles.section),
        const SizedBox(height: 4),
        _buildSpeedControl(),
        const SizedBox(height: 24),
        const Text('요일별 알람', style: AppTextStyles.section),
        const SizedBox(height: 10),
        _buildAlarmList(),
        const SizedBox(height: 10),
        Text(
          widget.settings.plan == StudyPlan.easy
              ? '이지 플랜은 월~금에만 알람이 울려요. 주말 알람은 스파르타 플랜에서 쓸 수 있어요.'
              : '스파르타 플랜은 주말에도 알람이 울리고, 배운 100단어에서 20문제를 냅니다.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 28),
        _buildActions(),
        const SizedBox(height: 28),
        _buildHowItWorks(),
        const SizedBox(height: 24),
        const Center(
          child: Text('WordWake v1.1.0', style: AppTextStyles.caption),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'W',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.background,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('WordWake', style: AppTextStyles.title),
            SizedBox(height: 2),
            Text('영어단어로 깨우는 아침', style: AppTextStyles.caption),
          ],
        ),
        const Spacer(),
        if (widget.settings.hasEnabledAlarm)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.alarm_on_rounded, size: 15, color: AppColors.accent),
                SizedBox(width: 4),
                Text('알람 켜짐', style: AppTextStyles.caption),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNextAlarmCard() {
    final DateTime? next = widget.alarmService
        .nextAlarm(widget.settings.alarms, widget.settings.plan);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('다음 알람', style: AppTextStyles.section),
          const SizedBox(height: 8),
          if (next == null) ...<Widget>[
            const Text(
              '꺼져 있어요',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '아래 요일별 알람에서 켜 주세요.',
              style: AppTextStyles.caption,
            ),
          ] else ...<Widget>[
            Text(
              '${_dayPrefix(next)} ${weekdayLabel(next.weekday)}요일 ${formatHourMinute(next.hour, next.minute)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.settings.plan.label} · ${widget.settings.plan.daysLabel} · ${widget.settings.level.label}',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  String _dayPrefix(DateTime time) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(time.year, time.month, time.day);
    final int diff = target.difference(today).inDays;
    if (diff == 0) {
      return '오늘';
    }
    if (diff == 1) {
      return '내일';
    }
    return '${time.month}월 ${time.day}일';
  }

  Widget _buildPlanCard(StudyPlan plan) {
    final bool selected = widget.settings.plan == plan;
    return GestureDetector(
      onTap: () => _selectPlan(plan),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(plan.label, style: AppTextStyles.title),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.daysLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.background : AppColors.mutedText,
                    ),
                  ),
                ),
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.summary, style: AppTextStyles.caption),
            if (plan == StudyPlan.easy) ...<Widget>[
              const SizedBox(height: 4),
              const Text(
                '월~목 20개 학습 → 퀴즈 5문제 · 금요일 복습 퀴즈 10문제',
                style: AppTextStyles.caption,
              ),
            ] else ...<Widget>[
              const SizedBox(height: 4),
              const Text(
                '월~금 20개 학습 → 퀴즈 5문제 · 주말 복습 퀴즈 20문제',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WordLevel.values.map((WordLevel level) {
        final bool selected = widget.settings.level == level;
        final int count = WordRepository.instance.isLoaded
            ? WordRepository.instance.countOf(level)
            : 0;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => _selectLevel(level),
          showCheckmark: false,
          label: Text(
            WordRepository.instance.isLoaded ? '${level.label} $count' : level.label,
          ),
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.background : AppColors.primaryText,
          ),
          selectedColor: AppColors.accent,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWordProgressCard() {
    return ListenableBuilder(
      listenable: WordProgressService.instance,
      builder: (BuildContext context, Widget? child) {
        final WordProgressService progress = WordProgressService.instance;
        final int weak = progress.weakWordCount;
        final int wrong = progress.totalWrong;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.replay_rounded,
                    size: 16,
                    color: weak > 0 ? AppColors.accent : AppColors.mutedText,
                  ),
                  const SizedBox(width: 6),
                  const Text('반복 학습', style: AppTextStyles.section),
                  const Spacer(),
                  if (weak > 0)
                    TextButton(
                      onPressed: () => progress.reset(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mutedText,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('기록 지우기', style: AppTextStyles.caption),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                weak > 0
                    ? '틀린 단어 $weak개 · 누적 오답 $wrong회'
                    : '아직 틀린 단어가 없어요',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 4),
              const Text(
                '틀린 단어는 다음 순환에서 먼저 다시 나와요. 맞히면 오답 횟수가 하나씩 줄어듭니다.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedControl() {
    final int seconds = widget.settings.studySeconds;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('단어당', style: AppTextStyles.body),
              const SizedBox(width: 6),
              Text(
                '$seconds초',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              const Text('1초 ~ 5초', style: AppTextStyles.caption),
            ],
          ),
          Slider(
            value: seconds.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$seconds초',
            onChanged: (double value) {
              widget.settings.setStudySeconds(value.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
            _buildAlarmRow(weekday),
        ],
      ),
    );
  }

  Widget _buildAlarmRow(int weekday) {
    final DayAlarm alarm = widget.settings.alarmFor(weekday);
    final bool activeDay = widget.settings.plan.isActiveWeekday(weekday);
    final bool enabled = alarm.enabled && activeDay;
    final bool isLast = weekday == DateTime.sunday;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 30,
                child: Text(
                  alarm.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: activeDay ? AppColors.primaryText : AppColors.mutedText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: activeDay ? () => _pickTime(weekday) : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40),
                  foregroundColor: AppColors.accent,
                ),
                child: Text(
                  alarm.timeLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: activeDay ? AppColors.accent : AppColors.mutedText,
                  ),
                ),
              ),
              const Spacer(),
              if (!activeDay)
                const Text('플랜 외', style: AppTextStyles.caption),
              Switch(
                value: enabled,
                onChanged: activeDay ? (bool value) => _toggleDay(weekday, value) : null,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _busy ? null : _ensurePermissions,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text(
              '권한 확인하고 알람 예약',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _openPreview,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text(
              '지금 미리보기 (알람 흐름 테스트)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('알람이 울리면', style: AppTextStyles.section),
          const SizedBox(height: 10),
          _howItWorksRow(
            Icons.menu_book_rounded,
            '단어 학습',
            '새 단어 20개가 ${widget.settings.studySeconds}초마다 자동으로 넘어가요.',
          ),
          const SizedBox(height: 10),
          _howItWorksRow(
            Icons.quiz_rounded,
            '2지선다 퀴즈',
            '한국어 뜻을 보고 영어 단어를 고르면 돼요. 틀리면 0.5초 뒤 다음 문제로 넘어갑니다.',
          ),
          const SizedBox(height: 10),
          _howItWorksRow(
            Icons.wb_sunny_rounded,
            '알람 꺼짐',
            widget.settings.plan == StudyPlan.easy
                ? '월~목 5문제, 금요일 10문제를 맞히면 해지 버튼이 켜져요.'
                : '월~금 5문제, 주말 20문제를 맞히면 해지 버튼이 켜져요.',
          ),
          const SizedBox(height: 10),
          _howItWorksRow(
            Icons.vibration_rounded,
            '소리와 진동',
            '처음 3초는 소리와 진동이 함께 울리고, 시작 버튼을 누르면 소리는 꺼지고 진동만 남아요.',
          ),
          const SizedBox(height: 10),
          _howItWorksRow(
            Icons.power_settings_new_rounded,
            '비상 종료',
            '왼쪽 위 비상 종료 버튼을 10초 동안 계속 누르면 알람이 꺼져요.',
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          const Text(
            '매달 마지막 금요일(이지) · 마지막 토·일요일(스파르타)은 그 달에 배운 단어 전체에서 복습 문제가 나와요.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _howItWorksRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
