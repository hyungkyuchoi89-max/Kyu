import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/word.dart';

/// 알람 직후 새 단어를 보여 주는 학습 화면.
///
/// [secondsPerWord]마다 자동으로 다음 단어로 넘어가고, 화면을 탭해도 넘어간다.
/// 마지막 단어가 끝나면 [onFinished]를 호출해 퀴즈로 이어 준다.
class StudyView extends StatefulWidget {
  const StudyView({
    super.key,
    required this.words,
    required this.secondsPerWord,
    required this.onFinished,
  });

  final List<Word> words;
  final int secondsPerWord;
  final VoidCallback onFinished;

  @override
  State<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<StudyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _index = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.secondsPerWord.clamp(1, 5).toInt()),
    )..addStatusListener(_handleStatus);
    if (widget.words.isEmpty) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
    } else {
      _controller.forward();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _advance();
    }
  }

  void _advance() {
    if (!mounted || _finished) {
      return;
    }
    if (_index >= widget.words.length - 1) {
      _finished = true;
      _controller.stop();
      widget.onFinished();
      return;
    }
    setState(() => _index += 1);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const SizedBox.shrink();
    }
    final Word word = widget.words[_index];
    final int total = widget.words.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('오늘의 단어', style: AppTextStyles.counter),
                  const Spacer(),
                  Text('${_index + 1} / $total', style: AppTextStyles.counter),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_index + 1) / total,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceElevated,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          color: AppColors.mutedText,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 10,
                            runSpacing: 4,
                            children: <Widget>[
                              Text(word.word, style: AppTextStyles.word),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(word.phonetic, style: AppTextStyles.phonetic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            word.meaning,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.meaning,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            '- ${word.example}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.example,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.secondsPerWord}초마다 자동으로 넘어가요 · 탭하면 바로 다음',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
