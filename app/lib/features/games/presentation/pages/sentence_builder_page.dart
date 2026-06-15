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

class SentenceBuilderPage extends ConsumerStatefulWidget {
  const SentenceBuilderPage({super.key, this.topic, this.translationLang});
  final String? topic;
  final String? translationLang;

  @override
  ConsumerState<SentenceBuilderPage> createState() =>
      _SentenceBuilderPageState();
}

class _Token {
  _Token({required this.id, required this.text});
  final int id;
  final String text;
}

class _SentenceBuilderPageState extends ConsumerState<SentenceBuilderPage> {
  SentenceBuilderDto? _data;
  String? _error;
  bool _loading = true;
  String _level = kAnyLevel;

  int _index = 0;
  late List<String> _targetTokens;
  late List<_Token> _bank;
  final List<_Token> _picked = <_Token>[];
  int _correctCount = 0;
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
      _picked.clear();
      _showFeedback = false;
    });
    try {
      final SentenceBuilderDto d = await ref
          .read(gamesRepositoryProvider)
          .generateSentenceBuilder(
            topic: widget.topic,
            count: 5,
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

  List<String> _tokenize(String s) {
    // Keep punctuation attached to words, split on whitespace.
    return s.trim().split(RegExp(r'\s+'));
  }

  void _setupCurrent() {
    final SentenceItemDto it = _data!.items[_index];
    _targetTokens = _tokenize(it.sentence);
    final List<_Token> shuffled = <_Token>[
      for (int i = 0; i < _targetTokens.length; i++)
        _Token(id: i, text: _targetTokens[i]),
    ];
    final Random rng = Random();
    for (int safety = 0; safety < 5; safety++) {
      shuffled.shuffle(rng);
      if (shuffled.map((t) => t.text).toList().join(' ') !=
          it.sentence.trim()) {
        break;
      }
    }
    _bank = shuffled;
    _picked.clear();
    _showFeedback = false;
  }

  void _pick(_Token t) {
    if (_showFeedback) return;
    setState(() {
      _bank.removeWhere((x) => x.id == t.id);
      _picked.add(t);
    });
  }

  void _unpick(_Token t) {
    if (_showFeedback) return;
    setState(() {
      _picked.removeWhere((x) => x.id == t.id);
      _bank.add(t);
    });
  }

  void _check() {
    final String built = _picked.map((t) => t.text).join(' ');
    final bool ok = built == _data!.items[_index].sentence.trim();
    setState(() {
      _showFeedback = true;
      _lastCorrect = ok;
      if (ok) _correctCount++;
    });
  }

  void _next() {
    if (_index >= _data!.items.length - 1) {
      setState(() => _index = _data!.items.length);
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
        titleKey: 'games.sentence_builder.title',
        icon: Icons.reorder_rounded,
        actions: <Widget>[
          IconButton(
            tooltip: 'games.rules'.tr(),
            onPressed: () => showGameRulesDialog(
              context,
              titleKey: 'games.sentence_builder.title',
              bodyKey: 'games.sentence_builder.rules',
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
    final SentenceBuilderDto d = _data!;
    if (_index >= d.items.length) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: GameDoneBar(
            title: 'games.done'.tr(),
            subtitle: 'games.score'.tr(
              args: <String>[
                _correctCount.toString(),
                d.items.length.toString(),
              ],
            ),
            onReplay: _load,
            onClose: () => context.pop(),
          ),
        ),
      );
    }

    final SentenceItemDto it = d.items[_index];

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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              it.translation,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _showFeedback
                    ? (_lastCorrect ? AppTheme.successGreen : AppTheme.errorRed)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: _showFeedback ? 2 : 1,
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _picked
                  .map((t) => _TokenChip(text: t.text, onTap: () => _unpick(t)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _bank
                .map(
                  (t) => _TokenChip(
                    text: t.text,
                    outlined: true,
                    onTap: () => _pick(t),
                  ),
                )
                .toList(),
          ),
          if (_showFeedback && !_lastCorrect) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'games.correct_answer'.tr(args: <String>[it.sentence]),
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: _showFeedback
                  ? FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: _lastCorrect
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                      child: Text(
                        _index == d.items.length - 1
                            ? 'common.finish'.tr()
                            : 'common.next'.tr(),
                      ),
                    )
                  : FilledButton(
                      onPressed: _picked.length == _targetTokens.length
                          ? _check
                          : null,
                      child: Text('common.check'.tr()),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.text,
    required this.onTap,
    this.outlined = false,
  });
  final String text;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return Material(
      color: outlined
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: outlined ? Border.all(color: color, width: 1.4) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
