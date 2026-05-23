import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/learning_models.dart';
import 'word_flashcard.dart';

/// Stage 1 — flashcard review. The user swipes through every word once.
/// The stage completes when the last card is reached AND has been flipped or
/// the user explicitly presses "I'm done". Auto-plays TTS on each card.
class CardsStage extends StatefulWidget {
  const CardsStage({
    super.key,
    required this.words,
    required this.onCompleted,
  });

  final List<WordDto> words;
  final VoidCallback onCompleted;

  @override
  State<CardsStage> createState() => _CardsStageState();
}

class _CardsStageState extends State<CardsStage> {
  late final PageController _controller;
  final WordTts _tts = WordTts();
  final Set<int> _viewed = <int>{};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _viewed.add(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.dispose();
    super.dispose();
  }

  void _speakCurrent() {
    final WordDto w = widget.words[_index];
    _tts.speak(w.lemma);
  }

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      _viewed.add(i);
    });
    _speakCurrent();
  }

  bool get _allViewed => _viewed.length >= widget.words.length;

  Future<void> _next() async {
    if (_index + 1 < widget.words.length) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (_allViewed) {
      widget.onCompleted();
    }
  }

  Future<void> _prev() async {
    if (_index > 0) {
      await _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.words.length;
    final double progress = (_index + 1) / total;
    final bool isLast = _index == total - 1;

    return Column(
      children: <Widget>[
        LinearProgressIndicator(value: progress, minHeight: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: <Widget>[
              Text('${_index + 1} / $total',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                'cards.tap_card_hint'.tr(),
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: total,
            itemBuilder: (BuildContext c, int i) {
              final WordDto w = widget.words[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: WordFlashcard(
                  key: ValueKey<int>(w.id),
                  word: w,
                  onSpeak: () => _tts.speak(w.lemma),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: _index > 0 ? _prev : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (isLast && _allViewed) ? widget.onCompleted : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          (isLast && _allViewed) ? AppTheme.successGreen : Theme.of(context).colorScheme.primary,
                    ),
                    icon: Icon(
                      (isLast && _allViewed)
                          ? Icons.lock_open_rounded
                          : Icons.chevron_right_rounded,
                    ),
                    label: Text(
                      (isLast && _allViewed)
                          ? 'cards.unlock_tests'.tr()
                          : 'common.next'.tr(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
