import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/translator_repository.dart';
import '../providers/translator_providers.dart';
import 'lang_pair_bar.dart';

class _VoiceMessage {
  _VoiceMessage({
    required this.fromLeft,
    required this.original,
    required this.translated,
  });
  final bool fromLeft;
  final String original;
  final String translated;
}

class TranslatorVoiceTab extends ConsumerStatefulWidget {
  const TranslatorVoiceTab({super.key});

  @override
  ConsumerState<TranslatorVoiceTab> createState() => _TranslatorVoiceTabState();
}

class _TranslatorVoiceTabState extends ConsumerState<TranslatorVoiceTab> {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _listening = false;
  bool? _listeningLeft;
  final List<_VoiceMessage> _messages = <_VoiceMessage>[];

  @override
  void initState() {
    super.initState();
    _stt.initialize().then((bool v) => setState(() => _ready = v));
  }

  Future<void> _listen({required bool fromLeft}) async {
    if (!_ready || _listening) return;
    final LangPair pair = ref.read(langPairProvider);
    final String localeCode = fromLeft ? pair.source : pair.target;

    setState(() {
      _listening = true;
      _listeningLeft = fromLeft;
    });

    String last = '';
    await _stt.listen(
      localeId: localeCode,
      onResult: (r) => last = r.recognizedWords,
    );
    // Wait until user stops talking. STT auto-stops; loop until done.
    while (_stt.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    setState(() {
      _listening = false;
      _listeningLeft = null;
    });
    if (last.trim().isEmpty) return;

    try {
      final TranslationResultDto r = await ref.read(translatorRepositoryProvider).translate(
            text: last,
            sourceLang: fromLeft ? pair.source : pair.target,
            targetLang: fromLeft ? pair.target : pair.source,
            mode: 'voice',
          );
      setState(() => _messages.add(_VoiceMessage(
            fromLeft: fromLeft,
            original: r.sourceText,
            translated: r.translatedText,
          )));
      await _tts.setLanguage(r.targetLang);
      await _tts.speak(r.translatedText);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LangPair pair = ref.watch(langPairProvider);
    return Column(
      children: <Widget>[
        const LangPairBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (BuildContext c, int i) {
              final _VoiceMessage m = _messages[i];
              final Alignment a = m.fromLeft ? Alignment.centerLeft : Alignment.centerRight;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Align(
                  alignment: a,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * 0.8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: m.fromLeft ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(m.original,
                              style: TextStyle(color: m.fromLeft ? Colors.black : Colors.white)),
                          const SizedBox(height: 4),
                          Text(m.translated,
                              style: TextStyle(
                                  color: m.fromLeft ? Colors.black54 : Colors.white70,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MicButton(
                    label: pair.source.toUpperCase(),
                    active: _listeningLeft == true,
                    onPressed: () => _listen(fromLeft: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MicButton(
                    label: pair.target.toUpperCase(),
                    active: _listeningLeft == false,
                    onPressed: () => _listen(fromLeft: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_ready)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('translator.stt_unavailable'.tr(),
                style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.label, required this.active, required this.onPressed});
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: active ? Colors.red : Theme.of(context).colorScheme.primary,
        minimumSize: const Size.fromHeight(56),
      ),
      icon: const Icon(Icons.mic),
      label: Text(label),
    );
  }
}
