import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 퀴즈를 통과한 뒤의 화면.
///
/// 이 화면에서 해지 버튼이 활성화된다. 버튼을 누르면 남아 있던 진동까지
/// 완전히 멈추고 알람이 끝난다.
class WakeUpView extends StatelessWidget {
  const WakeUpView({
    super.key,
    required this.studyCount,
    required this.correctCount,
    required this.targetCount,
    required this.clearedAt,
    required this.isPreview,
    required this.onDismiss,
  });

  final int studyCount;
  final int correctCount;
  final int targetCount;
  final DateTime clearedAt;
  final bool isPreview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final String hour = clearedAt.hour.toString().padLeft(2, '0');
    final String minute = clearedAt.minute.toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
        child: Column(
          children: <Widget>[
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                size: 52,
                color: AppColors.background,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isPreview ? '미리보기 완료' : '퀴즈 통과!',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$hour:$minute',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPreview
                  ? '실제 알람에서는 이 화면에서 해지 버튼이 켜져요.'
                  : '알람 소리는 꺼졌고 진동만 남아 있어요.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _StatChip(
                  icon: Icons.menu_book_rounded,
                  label: studyCount > 0 ? '학습 $studyCount단어' : '복습 퀴즈',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.check_circle_rounded,
                  label: '정답 $correctCount / $targetCount',
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isPreview ? '닫기' : '알람 해지',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPreview ? '닫으면 미리보기가 끝나요' : '해지하면 진동까지 완전히 멈춰요',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
