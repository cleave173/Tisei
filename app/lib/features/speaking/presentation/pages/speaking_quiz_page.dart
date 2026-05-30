import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../learning/data/learning_repository.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../data/speaking_repository.dart';

/// Speaking practice quiz: cycles through words for a topic+level, lets the
/// user record their pronunciation, scores it via the backend.
class SpeakingQuizPage extends ConsumerStatefulWidget {
  const SpeakingQuizPage({super.key, required this.topicId, this.level});
  final int topicId;
  final String? level;

  @override
  ConsumerState<SpeakingQuizPage> createState() => _SpeakingQuizPageState();
}

class _SpeakingQuizPageState extends ConsumerState<SpeakingQuizPage> {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  bool _listening = false;
  bool _evaluating = false;
  int _index = 0;
  String _recognizedDraft = '';
  SpeakingResultDto? _lastResult;

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

    String last = '';
    await _stt.listen(
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        last = r.recognizedWords;
        if (mounted) setState(() => _recognizedDraft = last);
      },
    );

    // Wait until user stops talking. STT auto-stops on silence.
    while (_stt.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() => _listening = false);
    await _evaluate(target, last);
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
      setState(() => _lastResult = r);
      if (r.isPass) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
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
    setState(() {
      _index += 1;
      _recognizedDraft = '';
      _lastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<WordDto>> words = ref.watch(
      wordsByTopicProvider(
        WordsQuery(topicId: widget.topicId, level: widget.level),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('speaking.title'.tr())),
      body: words.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<WordDto> list) {
          if (list.isEmpty) {
            return Center(child: Text('learning.no_words'.tr()));
          }
          if (_index >= list.length) {
            return _DoneView(
              total: list.length,
              onRestart: () => setState(() => _index = 0),
            );
          }
          final WordDto w = list[_index];
          final double progress = _index / list.length;
          return Column(
            children: <Widget>[
              LinearProgressIndicator(value: progress, minHeight: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: <Widget>[
                    Text(
                      '${_index + 1} / ${list.length}',
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
                        if (_lastResult != null)
                          _ResultBanner(result: _lastResult!),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        child: _MicButton(
                          listening: _listening,
                          evaluating: _evaluating,
                          ready: _sttReady,
                          onTap: _listening ? _stop : () => _start(w),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.evaluating,
    required this.ready,
    required this.onTap,
  });
  final bool listening;
  final bool evaluating;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = !ready
        ? 'speaking.mic_unavailable'.tr()
        : evaluating
        ? 'speaking.evaluating'.tr()
        : listening
        ? 'speaking.tap_to_stop'.tr()
        : 'speaking.tap_to_speak'.tr();
    final Color color = listening
        ? Colors.red
        : Theme.of(context).colorScheme.primary;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: ready ? color : Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      onPressed: ready && !evaluating ? onTap : null,
      icon: Icon(listening ? Icons.stop_circle : Icons.mic),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
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

  String _feedbackKey() => 'speaking.feedback.${result.feedback}';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.score}% · ${_feedbackKey().tr()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _color(),
                  ),
                ),
                Text(
                  result.isPass
                      ? 'speaking.pass_msg'.tr(
                          args: <String>[result.passThreshold.toString()],
                        )
                      : 'speaking.try_again_msg'.tr(
                          args: <String>[result.passThreshold.toString()],
                        ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.total, required this.onRestart});
  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.emoji_events, size: 96, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              'speaking.all_done'.tr(args: <String>[total.toString()]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: Text('speaking.restart'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
