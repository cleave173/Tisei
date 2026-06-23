import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/translator_repository.dart';
import '../providers/translator_providers.dart';
import 'lang_pair_bar.dart';

class TranslatorTextTab extends ConsumerStatefulWidget {
  const TranslatorTextTab({super.key});

  @override
  ConsumerState<TranslatorTextTab> createState() => _TranslatorTextTabState();
}

class _TranslatorTextTabState extends ConsumerState<TranslatorTextTab> {
  final TextEditingController _input = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  String _output = '';
  bool _busy = false;
  int? _historyId;
  bool _isFavorite = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_input.text.trim().isEmpty || _busy) return;
    final LangPair pair = ref.read(langPairProvider);
    final bool online = await checkOnline();

    if (!online) {
      if (mounted) AppSnackBar.showError(context, 'errors.no_internet'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      final TranslationResultDto r = await ref
          .read(translatorRepositoryProvider)
          .translate(
            text: _input.text,
            sourceLang: pair.source,
            targetLang: pair.target,
          );
      setState(() {
        _output = r.translatedText;
        _historyId = r.historyId;
        _isFavorite = false;
      });
      ref.invalidate(historyProvider(false));
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speak() async {
    if (_output.isEmpty) return;
    final LangPair pair = ref.read(langPairProvider);
    await _tts.setLanguage(pair.target);
    await _tts.speak(_output);
  }

  @override
  Widget build(BuildContext context) {
    final bool online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Column(
      children: <Widget>[
        const LangPairBar(),
        if (!online)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.orange.shade100,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 14,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'translator.offline_mode'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _input,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'translator.input_hint'.tr(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _translate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.translate),
                  label: Text('translator.translate'.tr()),
                ),
                const SizedBox(height: 16),
                if (_output.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(_output, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              onPressed: _speak,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: _output),
                              ),
                            ),
                            if (_historyId != null)
                              IconButton(
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: _isFavorite ? Colors.amber : null,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(translatorRepositoryProvider)
                                      .toggleFavorite(_historyId!);
                                  setState(() => _isFavorite = !_isFavorite);
                                  ref.invalidate(historyProvider(true));
                                },
                              ),
                          ],
                        ),
                      ],
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
