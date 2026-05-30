import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/learning_models.dart';
import 'word_flashcard.dart';

/// Stage: user hears each word (TTS) and types what they heard.
///
/// - Auto-plays the word on entry of each item.
/// - Accepts case-insensitive match, ignoring leading/trailing whitespace and
///   punctuation. Allows the user to "Reveal" after enough failed attempts.
/// - Completes the stage once every word has been typed correctly.
class ListeningStage extends StatefulWidget {
  const ListeningStage({
    super.key,
    required this.words,
    required this.onCompleted,
  });

  final List<WordDto> words;
  final VoidCallback onCompleted;

  @override
  State<ListeningStage> createState() => _ListeningStageState();
}

class _ListeningStageState extends State<ListeningStage> {
  final WordTts _tts = WordTts();
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  int _index = 0;
  int _attempts = 0;
  String? _feedback; // null | "correct" | "wrong"
  bool _revealed = false;
  bool _done = false;

  WordDto get _current => widget.words[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
  }

  @override
  void dispose() {
    _tts.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _playCurrent() async {
    await _tts.speak(_current.lemma);
  }

  String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-zA-Z\u00C0-\u024F'\s-]"), '')
        .trim();
  }

  void _check() {
    final String input = _norm(_ctrl.text);
    if (input.isEmpty) return;
    final bool ok = input == _norm(_current.lemma);
    setState(() {
      _attempts += 1;
      _feedback = ok ? 'correct' : 'wrong';
      if (ok) _revealed = false;
    });
    if (ok) {
      Future<void>.delayed(const Duration(milliseconds: 700), _advance);
    }
  }

  void _reveal() {
    setState(() {
      _revealed = true;
      _ctrl.text = _current.lemma;
    });
  }

  void _advance() {
    if (_index + 1 >= widget.words.length) {
      setState(() => _done = true);
      widget.onCompleted();
      return;
    }
    setState(() {
      _index += 1;
      _ctrl.clear();
      _attempts = 0;
      _feedback = null;
      _revealed = false;
    });
    _playCurrent();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _StageDoneView(
        icon: Icons.hearing_rounded,
        title: 'listening.done_title'.tr(),
        message: 'listening.done_msg'.tr(
          args: <String>['${widget.words.length}'],
        ),
        onContinue: () => Navigator.of(context).maybePop(),
      );
    }

    final double progress = _index / widget.words.length;
    return Column(
      children: <Widget>[
        LinearProgressIndicator(value: progress, minHeight: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: <Widget>[
              Text(
                '${_index + 1} / ${widget.words.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _current.cefrBadge,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 12),
                _BigPlayButton(onTap: _playCurrent),
                const SizedBox(height: 16),
                Text(
                  'listening.prompt'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    hintText: 'listening.input_hint'.tr(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (_feedback != null)
                  _FeedbackBanner(kind: _feedback!, lemma: _current.lemma),
                if (_attempts >= 2 &&
                    !_revealed &&
                    _feedback == 'wrong') ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _reveal,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('listening.reveal'.tr()),
                  ),
                ],
                if (_revealed) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'listening.revealed_msg'.tr(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _advance,
                    icon: const Icon(Icons.skip_next_rounded),
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
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.check_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'common.check'.tr(),
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

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: <Color>[
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.volume_up_rounded,
          color: Colors.white,
          size: 72,
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.kind, required this.lemma});
  final String kind;
  final String lemma;

  @override
  Widget build(BuildContext context) {
    final bool ok = kind == 'correct';
    final Color color = ok ? AppTheme.successGreen : AppTheme.errorRed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'listening.feedback_correct'.tr()
                  : 'listening.feedback_wrong'.tr(),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDoneView extends StatelessWidget {
  const _StageDoneView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onContinue,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 96, color: AppTheme.successGreen),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text('lesson.back_to_overview'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
