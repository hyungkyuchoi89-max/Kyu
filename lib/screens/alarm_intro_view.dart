import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 알람이 울린 직후의 첫 화면.
///
/// 소리와 진동이 함께 울리는 상태로 [waitDuration] 동안 머물고,
/// 그 뒤에야 시작 버튼이 활성화된다. (사용자가 알람을 바로 끄고 다시 잠드는 것을 막는다.)
class AlarmIntroView extends StatefulWidget {
  const AlarmIntroView({
    super.key,
    required this.now,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onStart,
    this.waitDuration = const Duration(seconds: 3),
  });

  final DateTime now;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onStart;
  final Duration waitDuration;

  @override
  State<AlarmIntroView> createState() => _AlarmIntroViewState();
}

class _AlarmIntroViewState extends State<AlarmIntroView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.waitDuration,
    )
      ..addStatusListener(_handleStatus)
      ..forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String time =
        '${widget.now.hour.toString().padLeft(2, '0')}:${widget.now.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
        child: Column(
          children: <Widget>[
            const Spacer(),
            const Text('좋은 아침이에요', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '알람이 울리고 있어요',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 36),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    widget.title,
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 96,
              height: 96,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  final int remaining = (widget.waitDuration.inMilliseconds *
                          (1 - _controller.value) /
                          1000)
                      .ceil();
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 5,
                          backgroundColor: AppColors.surfaceElevated,
                          color: AppColors.accent,
                        ),
                      ),
                      _ready
                          ? const Icon(
                              Icons.play_arrow_rounded,
                              size: 36,
                              color: AppColors.accent,
                            )
                          : Text(
                              '$remaining',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _ready ? '이제 시작할 수 있어요' : '잠깐만요, 곧 시작할 수 있어요',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: _ready ? widget.onStart : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.surfaceElevated,
                  disabledForegroundColor: AppColors.mutedText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.buttonLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '시작하면 알람 소리는 멈추고 진동만 남아요',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
