import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/learning_models.dart';

/// A flashcard for a single [WordDto]. Tap to flip between:
///   - front: word, IPA, "Play" (TTS) button
///   - back: translation + example sentence (+ its translation)
///
/// The flip uses a Y-axis 3D rotation. Each side is rendered independently
/// so it stays readable (no mirror) by using a counter-rotation on the back.
class WordFlashcard extends StatefulWidget {
  const WordFlashcard({super.key, required this.word, this.onSpeak});

  final WordDto word;
  final VoidCallback? onSpeak;

  @override
  State<WordFlashcard> createState() => _WordFlashcardState();
}

class _WordFlashcardState extends State<WordFlashcard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _showBack = !_showBack);
    if (_showBack) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant WordFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to front when the word changes (e.g. swipe between cards).
    if (oldWidget.word.id != widget.word.id && _showBack) {
      _showBack = false;
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (BuildContext context, Widget? child) {
          final double angle = _anim.value * math.pi; // 0 .. π
          final bool showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardBack(word: widget.word),
                  )
                : _CardFront(word: widget.word, onSpeak: widget.onSpeak),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word, this.onSpeak});
  final WordDto word;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: LinearGradient(
        colors: <Color>[
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              word.cefrBadge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          Text(
            word.lemma,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          if ((word.transcriptionIpa ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '/${word.transcriptionIpa}/',
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                ),
              ),
            ),
          if ((word.partOfSpeech ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                word.partOfSpeech!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onSpeak,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70, width: 1.5),
              minimumSize: const Size(160, 44),
            ),
            icon: const Icon(Icons.volume_up_rounded),
            label: Text('common.play'.tr()),
          ),
          const Spacer(),
          Text(
            'cards.tap_to_flip'.tr(),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word});
  final WordDto word;

  @override
  Widget build(BuildContext context) {
    final String localeCode = Localizations.localeOf(context).languageCode;
    final String translation = word.localizedTranslation(localeCode);
    final String? exampleTranslation = word.localizedExampleTranslation(localeCode);

    return _CardShell(
      color: Colors.white,
      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              'cards.translation'.tr(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              translation.isEmpty ? '—' : translation,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            if ((word.exampleSentence ?? '').isNotEmpty) ...<Widget>[
              Text(
                'cards.example'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                word.exampleSentence!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.35,
                ),
              ),
              if ((exampleTranslation ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  exampleTranslation!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ],
            const Spacer(),
            Center(
              child: Text(
                'cards.tap_to_flip_back'.tr(),
                style: const TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.gradient,
    this.color,
    this.border,
  });
  final Widget child;
  final LinearGradient? gradient;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: border,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Helper to construct + dispose a TTS instance for a given language.
class WordTts {
  WordTts({this.locale = 'en-US'}) {
    _tts.setLanguage(locale);
    _tts.setSpeechRate(0.45);
  }
  final FlutterTts _tts = FlutterTts();
  final String locale;

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
