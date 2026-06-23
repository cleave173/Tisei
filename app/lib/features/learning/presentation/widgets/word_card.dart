import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/learning_models.dart';

/// Vocabulary card: lemma + IPA + translation + TTS audio playback.
/// Uses on-device TTS (flutter_tts) — no network needed.
class WordCard extends StatefulWidget {
  const WordCard({super.key, required this.word});
  final WordDto word;

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  bool _speaking = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty || _speaking) return;
    await _ensureInit();
    setState(() => _speaking = true);
    try {
      await _tts.stop();
      await _tts.speak(text);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WordDto w = widget.word;
    final String lang = context.locale.languageCode;
    final String? exTr = w.localizedExampleTranslation(lang);
    final String tr = w.localizedTranslation(lang);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        w.lemma,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (w.transcriptionIpa != null &&
                          w.transcriptionIpa!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '/${w.transcriptionIpa}/',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _LevelBadge(level: w.cefrBadge),
                const SizedBox(width: 8),
                _SpeakButton(speaking: _speaking, onTap: () => _speak(w.lemma)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (w.partOfSpeech != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      w.partOfSpeech!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(child: Text(tr, style: const TextStyle(fontSize: 16))),
              ],
            ),
            if (w.exampleSentence != null &&
                w.exampleSentence!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          w.exampleSentence!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (exTr != null && exTr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              exTr,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'common.play'.tr(),
                    onPressed: () => _speak(w.exampleSentence!),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final String level;

  Color _color() {
    if (level.startsWith('A')) return Colors.green;
    if (level.startsWith('B')) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _color(),
        ),
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.speaking, required this.onTap});
  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: speaking
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          speaking ? Icons.volume_up : Icons.volume_up_outlined,
          color: speaking
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
