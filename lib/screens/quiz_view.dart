import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/quiz_engine.dart';
import '../models/word.dart';

/// 한국어 뜻 → 영어 단어 2지선다 퀴즈.
///
/// - 틀리면 배경이 빨간색(#DC2626)으로 변하고 0.5초 뒤 다음 문제로 넘어간다.
/// - 정답을 [target]개 맞히면 [onFinished]를 호출한다.
/// - 풀을 다 쓰면 다시 섞어서 목표에 닿을 때까지 계속 낸다.
class QuizView extends StatefulWidget {
  const QuizView({
    super.key,
    required this.pool,
    required this.target,
    required this.onFinished,
    this.wrongCounts = const <String, int>{},
    this.onAnswered,
  });

  final List<Word> pool;
  final int target;
  final ValueChanged<int> onFinished;

  /// 단어 id → 지금까지 틀린 횟수. 많은 단어를 먼저 낸다.
  final Map<String, int> wrongCounts;

  /// 문제를 풀 때마다 호출된다(정답 여부 포함). 오답 기록 저장에 쓴다.
  final void Function(Word word, bool correct)? onAnswered;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  late final QuizEngine _engine;
  late QuizQuestion _question;
  Timer? _timer;
  int _correct = 0;
  bool _locked = false;
  bool _finished = false;
  String? _selectedId;
  Color _background = Colors.transparent;

  static const Duration _wrongDelay = Duration(milliseconds: 500);
  static const Duration _correctDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _engine = QuizEngine(pool: widget.pool, wrongCounts: widget.wrongCounts);
    _question = _engine.next();
  }

  void _answer(Word option) {
    if (_locked || _finished) {
      return;
    }
    final bool isCorrect = option.id == _question.answer.id;
    _timer?.cancel();
    widget.onAnswered?.call(_question.answer, isCorrect);
    setState(() {
      _locked = true;
      _selectedId = option.id;
      if (isCorrect) {
        _correct += 1;
      }
      _background = isCorrect ? const Color(0xFF14532D) : AppColors.danger;
    });
    _timer = Timer(isCorrect ? _correctDelay : _wrongDelay, _next);
  }

  void _next() {
    if (!mounted || _finished) {
      return;
    }
    if (_correct >= widget.target) {
      _finished = true;
      widget.onFinished(_correct);
      return;
    }
    setState(() {
      _question = _engine.next();
      _locked = false;
      _selectedId = null;
      _background = Colors.transparent;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress =
        (_correct / widget.target).clamp(0.0, 1.0).toDouble();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '$_correct / ${widget.target}',
                    style: AppTextStyles.counter,
                  ),
                  const Spacer(),
                  Text(
                    '정답 ${widget.target}개면 알람 꺼짐',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceElevated,
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '다음 뜻에 맞는 단어는?',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _question.answer.meaning,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildOption(_question.options[0]),
                        const SizedBox(height: 12),
                        _buildOption(_question.options[1]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _locked
                    ? (_selectedId == _question.answer.id ? '정답이에요!' : '아쉬워요, 다음 문제로 넘어갑니다')
                    : '뜻을 보고 영어 단어를 고르세요',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(Word option) {
    final bool isAnswer = option.id == _question.answer.id;
    final bool isSelected = option.id == _selectedId;

    Color borderColor = AppColors.border;
    Widget? trailing;

    if (_locked) {
      if (isAnswer) {
        borderColor = AppColors.success;
        trailing = const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 22,
        );
      } else if (isSelected) {
        borderColor = AppColors.primaryText;
        trailing = const Icon(
          Icons.cancel_rounded,
          color: AppColors.primaryText,
          size: 22,
        );
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 86,
      child: OutlinedButton(
        onPressed: _locked ? null : () => _answer(option),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: BorderSide(color: borderColor, width: 1.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          foregroundColor: AppColors.primaryText,
          disabledForegroundColor: AppColors.primaryText,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(option.word, style: AppTextStyles.optionWord),
            if (trailing != null)
              Positioned(right: 4, child: trailing),
          ],
        ),
      ),
    );
  }
}
