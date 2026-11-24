import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// 비상 종료 버튼.
///
/// 알람을 정상적으로 끄려면 퀴즈를 통과해야 하지만, 급한 상황을 위해
/// 왼쪽 위 모서리에서 10초 동안 계속 누르고 있으면 알람이 꺼진다.
/// 누르는 동안 남은 시간이 원형 게이지로 표시된다.
class EmergencyDismissButton extends StatefulWidget {
  const EmergencyDismissButton({
    super.key,
    required this.onTriggered,
    this.holdDuration = const Duration(seconds: 10),
  });

  final VoidCallback onTriggered;
  final Duration holdDuration;

  @override
  State<EmergencyDismissButton> createState() => _EmergencyDismissButtonState();
}

class _EmergencyDismissButtonState extends State<EmergencyDismissButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onTriggered();
    }
  }

  void _startHolding() {
    if (_controller.value >= 1) {
      return;
    }
    _controller.forward();
  }

  void _stopHolding() {
    if (_controller.value >= 1) {
      return;
    }
    _controller.animateBack(0, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '비상 종료. 10초 동안 길게 누르면 알람이 꺼집니다.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _startHolding(),
        onPointerUp: (_) => _stopHolding(),
        onPointerCancel: (_) => _stopHolding(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double value = _controller.value;
            final int remaining =
                (widget.holdDuration.inMilliseconds * (1 - value) / 1000).ceil();
            final bool holding = value > 0;
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 4,
                            backgroundColor: AppColors.surfaceElevated,
                            color: AppColors.danger,
                          ),
                        ),
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 20,
                          color: holding ? AppColors.danger : AppColors.mutedText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    holding ? '${remaining}s' : '비상 종료',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: holding ? AppColors.danger : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
