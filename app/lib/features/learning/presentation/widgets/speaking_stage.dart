import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../speaking/data/speaking_repository.dart';
import '../../data/models/learning_models.dart';

/// Embeddable speaking practice — same engine as the standalone speaking quiz,
/// but loops only over the words passed in. Calls `onCompleted` after the
/// user passes every word (or chooses to skip past the last one).
class SpeakingStage extends ConsumerStatefulWidget {
  const SpeakingStage({
    super.key,
    required this.words,
    required this.onCompleted,
  });

  final List<WordDto> words;
  final VoidCallback onCompleted;

  @override
  ConsumerState<SpeakingStage> createState() => _SpeakingStageState();
}

class _SpeakingStageState extends ConsumerState<SpeakingStage> {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  bool _listening = false;
  bool _evaluating = false;
  int _index = 0;
  String _recognizedDraft = '';
  SpeakingResultDto? _lastResult;
  int _passedCount = 0;

  @override
  void initState() {
    super.initState();
    _initStt();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final PermissionStatus mic = await Permission.microphone.request();
    final PermissionStatus speech = await Permission.speech.request();
    if (mic.isDenied || speech.isDenied) return;
    final bool ok = await _stt.initialize(
      onError: (Object e) => debugPrint('STT error: $e'),
      onStatus: (String s) => debugPrint('STT status: $s'),
    );
    if (mounted) setState(() => _sttReady = ok);
  }

  Future<void> _playTarget(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _start(WordDto target) async {
    if (_listening || _evaluating || !_sttReady) return;
    setState(() {
      _listening = true;
      _recognizedDraft = '';
      _lastResult = null;
    });

    String lastRecognized = '';
    await _stt.listen(
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        final String text = r.recognizedWords.trim();
        if (text.isEmpty) return;
        lastRecognized = text;
        if (mounted) setState(() => _recognizedDraft = text);
      },
    );
    while (_stt.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() => _listening = false);
    final String recognized = lastRecognized.isNotEmpty
        ? lastRecognized
        : _recognizedDraft;
    await _evaluate(target, recognized);
  }

  Future<void> _stop() async {
    await _stt.stop();
  }

  Future<void> _evaluate(WordDto target, String recognized) async {
    setState(() => _evaluating = true);
    try {
      final SpeakingResultDto r = await ref
          .read(speakingRepositoryProvider)
          .evaluate(targetText: target.lemma, recognizedText: recognized);
      if (!mounted) return;
      setState(() {
        _lastResult = r;
        if (r.isPass) _passedCount += 1;
      });
      if (r.isPass) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        _next();
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  void _next() {
    if (_index + 1 >= widget.words.length) {
      // Stage cleared if at least 60% of words were pronounced correctly.
      if (_passedCount * 100 ~/ widget.words.length >= 60) {
        widget.onCompleted();
      }
      setState(() {
        _index = widget.words.length; // marker for "done"
        _recognizedDraft = '';
        _lastResult = null;
      });
      return;
    }
    setState(() {
      _index += 1;
      _recognizedDraft = '';
      _lastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.words.length;
    if (_index >= total) {
      final int score = _passedCount * 100 ~/ total;
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
                passed
                    ? 'speaking.stage_pass'.tr()
                    : 'speaking.stage_fail'.tr(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_passedCount / $total · $score%',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
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

    final WordDto w = widget.words[_index];
    final double progress = _index / total;
    return Column(
      children: <Widget>[
        LinearProgressIndicator(value: progress, minHeight: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: <Widget>[
              Text(
                '${_index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                w.cefrBadge,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    w.lemma,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (w.transcriptionIpa != null &&
                      w.transcriptionIpa!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '/${w.transcriptionIpa}/',
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _playTarget(w.lemma),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text('common.play'.tr()),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'speaking.tap_to_record'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_recognizedDraft.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        '"$_recognizedDraft"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (_lastResult != null) _ResultBanner(result: _lastResult!),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _evaluating || _listening ? null : _next,
                    icon: const Icon(Icons.skip_next),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'common.skip'.tr(),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _listening
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _sttReady && !_evaluating
                        ? (_listening ? _stop : () => _start(w))
                        : null,
                    icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        !_sttReady
                            ? 'speaking.mic_unavailable'.tr()
                            : _evaluating
                            ? 'speaking.evaluating'.tr()
                            : _listening
                            ? 'speaking.tap_to_stop'.tr()
                            : 'speaking.tap_to_speak'.tr(),
                        maxLines: 1,
                        softWrap: false,
                      ),
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

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final SpeakingResultDto result;

  Color _color() {
    if (result.isPass) return AppTheme.successGreen;
    if (result.score >= 60) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _icon() {
    if (result.isPass) return Icons.check_circle;
    if (result.score >= 60) return Icons.trending_up;
    return Icons.refresh;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color().withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(_icon(), color: _color(), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${result.score}% · ${('speaking.feedback.${result.feedback}').tr()}',
              style: TextStyle(fontWeight: FontWeight.w700, color: _color()),
            ),
          ),
        ],
      ),
    );
  }
}
