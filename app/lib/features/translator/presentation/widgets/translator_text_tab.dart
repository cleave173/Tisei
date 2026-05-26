import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/ml_kit_translator_service.dart';
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
  bool _downloading = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_input.text.trim().isEmpty || _busy) return;
    final LangPair pair = ref.read(langPairProvider);
    final bool online = await checkOnline();

    setState(() => _busy = true);
    try {
      if (online) {
        final TranslationResultDto r = await ref
            .read(translatorRepositoryProvider)
            .translate(text: _input.text, sourceLang: pair.source, targetLang: pair.target);
        setState(() => _output = r.translatedText);
        ref.invalidate(historyProvider(false));
      } else {
        await _translateOffline(pair);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _translateOffline(LangPair pair) async {
    final MlKitTranslatorService svc = ref.read(mlKitTranslatorServiceProvider);
    final bool srcReady = await svc.isDownloaded(pair.source);
    final bool tgtReady = await svc.isDownloaded(pair.target);

    if (!srcReady || !tgtReady) {
      if (!mounted) return;
      final bool? ok = await _showDownloadDialog(pair, srcReady, tgtReady);
      if (ok != true) return;
      setState(() => _downloading = true);
      try {
        if (!srcReady) await svc.downloadModel(pair.source);
        if (!tgtReady) await svc.downloadModel(pair.target);
      } finally {
        if (mounted) setState(() => _downloading = false);
      }
    }

    final String? result = await svc.translate(
      text: _input.text,
      sourceLang: pair.source,
      targetLang: pair.target,
    );
    if (result == null) {
      if (mounted) AppSnackBar.showError(context, 'translator.offline_unsupported'.tr());
      return;
    }
    setState(() => _output = result);
  }

  Future<bool?> _showDownloadDialog(LangPair pair, bool srcReady, bool tgtReady) {
    final List<String> missing = <String>[
      if (!srcReady) pair.source.toUpperCase(),
      if (!tgtReady) pair.target.toUpperCase(),
    ];
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('translator.offline_model_title'.tr()),
        content: Text('translator.offline_model_body'.tr(args: <String>[missing.join(', ')])),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded),
            label: Text('translator.download'.tr()),
          ),
        ],
      ),
    );
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
                Icon(Icons.offline_bolt_rounded, size: 14, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'translator.offline_mode'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
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
                  decoration: InputDecoration(hintText: 'translator.input_hint'.tr()),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_busy || _downloading) ? null : _translate,
                  icon: (_busy || _downloading)
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(online ? Icons.translate : Icons.offline_bolt_rounded),
                  label: Text(_downloading ? 'translator.downloading'.tr() : 'translator.translate'.tr()),
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
                              onPressed: () =>
                                  Clipboard.setData(ClipboardData(text: _output)),
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
