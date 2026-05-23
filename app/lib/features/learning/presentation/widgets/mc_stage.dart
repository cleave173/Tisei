import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/learning_models.dart';

/// Stage: pick the correct translation of the shown word from 4 options.
///
/// Options are generated client-side from sibling words in the same lesson
/// (their localized translations act as distractors). If the lesson has < 4
/// words, options will be padded with placeholders.
class MultipleChoiceStage extends StatefulWidget {
  const MultipleChoiceStage({
    super.key,
    required this.words,
    required this.onCompleted,
  });

  final List<WordDto> words;
  final VoidCallback onCompleted;

  @override
  State<MultipleChoiceStage> createState() => _MultipleChoiceStageState();
}

class _MultipleChoiceStageState extends State<MultipleChoiceStage> {
  List<_McQuestion>? _questions;
  int _index = 0;
  int? _pickedIndex;
  bool _wasCorrect = false;
  int _correctCount = 0;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build questions once we know the active locale (needed for translations).
    if (_questions == null) {
      final String localeCode = Localizations.localeOf(context).languageCode;
      _questions = _buildQuestions(widget.words, localeCode);
    }
  }

  List<_McQuestion> _buildQuestions(List<WordDto> words, String localeCode) {
    final Random rng = Random();
    final List<String> allTranslations = words
        .map((WordDto w) => w.localizedTranslation(localeCode))
        .where((String s) => s.isNotEmpty)
        .toSet()
        .toList();

    final List<_McQuestion> out = <_McQuestion>[];
    for (final WordDto w in words) {
      final String correct = w.localizedTranslation(localeCode);
      if (correct.isEmpty) continue;
      final List<String> distractors = allTranslations
          .where((String s) => s != correct)
          .toList()
        ..shuffle(rng);
      final List<String> options = <String>[correct, ...distractors.take(3)];
      // Pad with em-dashes if not enough distractors (tiny lessons).
      while (options.length < 4) {
        options.add('—');
      }
      options.shuffle(rng);
      out.add(_McQuestion(
        word: w,
        correctIndex: options.indexOf(correct),
        options: options,
      ));
    }
    out.shuffle(rng);
    return out;
  }

  _McQuestion get _q => _questions![_index];

  void _pick(int i) {
    if (_pickedIndex != null) return;
    setState(() {
      _pickedIndex = i;
      _wasCorrect = i == _q.correctIndex;
      if (_wasCorrect) _correctCount += 1;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), _advance);
  }

  void _advance() {
    if (_index + 1 >= _questions!.length) {
      setState(() => _done = true);
      // Require at least 60% correct to mark the stage as cleared.
      if (_correctCount * 100 ~/ _questions!.length >= 60) {
        widget.onCompleted();
      }
      return;
    }
    setState(() {
      _index += 1;
      _pickedIndex = null;
      _wasCorrect = false;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _pickedIndex = null;
      _wasCorrect = false;
      _correctCount = 0;
      _done = false;
      _questions!.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_questions!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('mc.no_translations'.tr(), textAlign: TextAlign.center),
        ),
      );
    }
    if (_done) {
      final int total = _questions!.length;
      final int score = _correctCount * 100 ~/ total;
      final bool passed = score >= 60;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                size: 96,
                color: passed ? Colors.amber : AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'mc.done_pass'.tr() : 'mc.done_fail'.tr(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('$_correctCount / $total · $score%',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              if (!passed)
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('common.retry'.tr()),
                )
              else
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text('lesson.back_to_overview'.tr()),
                ),
            ],
          ),
        ),
      );
    }

    final String localeCode = Localizations.localeOf(context).languageCode;
    final double progress = _index / _questions!.length;
    return Column(
      children: <Widget>[
        LinearProgressIndicator(value: progress, minHeight: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: <Widget>[
              Text('${_index + 1} / ${_questions!.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_q.word.cefrBadge,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  )),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 12),
                Text(
                  'mc.prompt'.tr(),
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _q.word.lemma,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if ((_q.word.transcriptionIpa ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '/${_q.word.transcriptionIpa}/',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ..._q.options.asMap().entries.map((MapEntry<int, String> e) {
                  final bool isPicked = _pickedIndex == e.key;
                  final bool isCorrect = e.key == _q.correctIndex;
                  Color? bg;
                  Color? fg;
                  if (_pickedIndex != null) {
                    if (isCorrect) {
                      bg = AppTheme.successGreen.withValues(alpha: 0.15);
                      fg = AppTheme.successGreen;
                    } else if (isPicked) {
                      bg = AppTheme.errorRed.withValues(alpha: 0.15);
                      fg = AppTheme.errorRed;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _pickedIndex == null ? () => _pick(e.key) : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: bg,
                          foregroundColor: fg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }),
                if (_pickedIndex != null && !_wasCorrect) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'mc.correct_was'.tr(args: <String>[
                      _q.word.localizedTranslation(localeCode),
                    ]),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _McQuestion {
  const _McQuestion({
    required this.word,
    required this.correctIndex,
    required this.options,
  });
  final WordDto word;
  final int correctIndex;
  final List<String> options;
}
