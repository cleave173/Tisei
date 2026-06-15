import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/games_repository.dart';
import '../../data/models/game_dtos.dart';
import '../widgets/game_widgets.dart';

class WordScramblePage extends ConsumerStatefulWidget {
  const WordScramblePage({super.key, this.topic, this.translationLang});
  final String? topic;
  final String? translationLang;

  @override
  ConsumerState<WordScramblePage> createState() => _WordScramblePageState();
}

class _WordScramblePageState extends ConsumerState<WordScramblePage> {
  WordScrambleDto? _data;
  String? _error;
  bool _loading = true;
  String _level = kAnyLevel;

  int _index = 0;
  late List<_LetterSlot> _scrambled;
  final List<_LetterSlot> _picked = <_LetterSlot>[];
  int _correctCount = 0;
  int _wrong = 0;
  bool _showFeedback = false;
  bool _lastCorrect = false;

  @override
  void initState() {
    super.initState();
    final String? userLevel = readUserCefrLevel(ref);
    if (userLevel != null && userLevel.isNotEmpty) {
      _level = userLevel.toUpperCase();
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _index = 0;
      _correctCount = 0;
      _wrong = 0;
      _showFeedback = false;
      _picked.clear();
    });
    try {
      final WordScrambleDto d = await ref
          .read(gamesRepositoryProvider)
          .generateWordScramble(
            topic: widget.topic,
            count: 8,
            level: _level,
            translationLang: widget.translationLang,
          );
      setState(() {
        _data = d;
        _loading = false;
        _setupCurrent();
      });
    } catch (e) {
      setState(() {
        _error = AppSnackBar.friendlyMessage(e);
        _loading = false;
      });
    }
  }

  void _setupCurrent() {
    final String word = _data!.items[_index].word.toLowerCase();
    final List<String> chars = word.split('');
    final Random rng = Random();
    // Re-shuffle if accidentally already in order with >1 letter.
    for (int safety = 0; safety < 5; safety++) {
      chars.shuffle(rng);
      if (chars.join('') != word) break;
    }
    _scrambled = <_LetterSlot>[
      for (int i = 0; i < chars.length; i++) _LetterSlot(id: i, ch: chars[i]),
    ];
    _picked.clear();
    _showFeedback = false;
  }

  void _pick(_LetterSlot s) {
    if (_showFeedback) return;
    setState(() {
      _scrambled = _scrambled.where((l) => l.id != s.id).toList();
      _picked.add(s);
    });
    _checkIfFilled();
  }

  void _unpick(_LetterSlot s) {
    if (_showFeedback) return;
    setState(() {
      _picked.removeWhere((l) => l.id == s.id);
      _scrambled.add(s);
    });
  }

  void _checkIfFilled() {
    final String built = _picked.map((l) => l.ch).join('');
    final String target = _data!.items[_index].word.toLowerCase();
    if (built.length < target.length) return;
    final bool ok = built == target;
    setState(() {
      _showFeedback = true;
      _lastCorrect = ok;
      if (ok) {
        _correctCount++;
      } else {
        _wrong++;
      }
    });
  }

  void _next() {
    if (_index >= _data!.items.length - 1) {
      setState(() => _index = _data!.items.length); // mark finished
      return;
    }
    setState(() {
      _index++;
      _setupCurrent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: buildGameAppBar(
        context,
        titleKey: 'games.word_scramble.title',
        icon: Icons.sort_by_alpha_rounded,
        actions: <Widget>[
          IconButton(
            tooltip: 'games.rules'.tr(),
            onPressed: () => showGameRulesDialog(
              context,
              titleKey: 'games.word_scramble.title',
              bodyKey: 'games.word_scramble.rules',
            ),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'games.level_pick'.tr(),
            onPressed: () async {
              final String? picked = await showLevelPickerDialog(
                context,
                currentLevel: _level,
                userLevel: readUserCefrLevel(ref),
              );
              if (picked != null && picked != _level) {
                setState(() => _level = picked);
                _load();
              }
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return GameErrorView(message: _error!, onRetry: _load);
    final WordScrambleDto d = _data!;
    if (_index >= d.items.length) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: GameDoneBar(
            title: 'games.done'.tr(),
            subtitle:
                '${'games.score'.tr(args: <String>[_correctCount.toString(), d.items.length.toString()])}${_wrong > 0 ? ' \u00B7 ${'games.mistakes'.tr(args: <String>[_wrong.toString()])}' : ''}',
            onReplay: _load,
            onClose: () => context.pop(),
          ),
        ),
      );
    }

    final ScrambleItemDto it = d.items[_index];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GameHeader(
            level: d.level,
            topic: d.topicLabel,
            trailing: '${_index + 1}/${d.items.length}',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  it.translation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (it.hint != null && it.hint!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    it.hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          _LetterRow(
            letters: _picked,
            emptySlots: it.word.length - _picked.length,
            onTap: _showFeedback ? null : _unpick,
            target: it.word,
            feedback: _showFeedback ? _lastCorrect : null,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _scrambled
                .map((l) => _LetterChip(letter: l.ch, onTap: () => _pick(l)))
                .toList(),
          ),
          const Spacer(),
          if (_showFeedback)
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _lastCorrect
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                  child: Text(
                    _lastCorrect
                        ? (_index == d.items.length - 1
                              ? 'common.finish'.tr()
                              : 'common.next'.tr())
                        : 'games.show_answer'.tr(
                            args: <String>[it.word.toUpperCase()],
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LetterSlot {
  _LetterSlot({required this.id, required this.ch});
  final int id;
  final String ch;
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.letter, this.onTap});
  final String letter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 52,
          alignment: Alignment.center,
          child: Text(
            letter.toUpperCase(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  const _LetterRow({
    required this.letters,
    required this.emptySlots,
    required this.onTap,
    required this.target,
    this.feedback,
  });

  final List<_LetterSlot> letters;
  final int emptySlots;
  final void Function(_LetterSlot)? onTap;
  final String target;
  final bool? feedback;

  @override
  Widget build(BuildContext context) {
    final Color color = feedback == null
        ? Theme.of(context).colorScheme.primary
        : (feedback! ? AppTheme.successGreen : AppTheme.errorRed);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: <Widget>[
        ...letters.map(
          (l) => _LetterSlotBox(
            letter: l.ch,
            color: color,
            onTap: () => onTap?.call(l),
          ),
        ),
        for (int i = 0; i < emptySlots; i++)
          _LetterSlotBox(letter: '', color: Colors.grey, onTap: null),
      ],
    );
  }
}

class _LetterSlotBox extends StatelessWidget {
  const _LetterSlotBox({required this.letter, required this.color, this.onTap});
  final String letter;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: color, width: 2)),
        ),
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
