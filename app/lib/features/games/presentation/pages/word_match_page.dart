import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/games_repository.dart';
import '../../data/models/game_dtos.dart';
import '../widgets/game_widgets.dart';

class WordMatchPage extends ConsumerStatefulWidget {
  const WordMatchPage({super.key, this.topic});
  final String? topic;

  @override
  ConsumerState<WordMatchPage> createState() => _WordMatchPageState();
}

class _WordMatchPageState extends ConsumerState<WordMatchPage> {
  WordMatchDto? _data;
  String? _error;
  bool _loading = true;
  String _level = kAnyLevel; // overwritten in initState if user has a level

  // Game state
  final Set<int> _matched = <int>{};
  int? _selectedLeft;
  int? _selectedRight;
  int _wrongTaps = 0;
  late List<String> _leftWords;
  late List<String> _rightTranslations;
  late List<int> _rightToLeft; // rightTranslations[i] -> matching left index

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
      _matched.clear();
      _selectedLeft = null;
      _selectedRight = null;
      _wrongTaps = 0;
    });
    try {
      final WordMatchDto d = await ref
          .read(gamesRepositoryProvider)
          .generateWordMatch(topic: widget.topic, count: 8, level: _level);
      _leftWords = d.pairs.map((p) => p.word).toList();
      _rightTranslations = d.pairs.map((p) => p.translation).toList();
      _rightToLeft = List<int>.generate(d.pairs.length, (i) => i);
      _rightToLeft.shuffle();
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppSnackBar.friendlyMessage(e);
        _loading = false;
      });
    }
  }

  void _tryMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;
    final int rightLeftIdx = _rightToLeft[_selectedRight!];
    if (rightLeftIdx == _selectedLeft) {
      setState(() {
        _matched.add(_selectedLeft!);
        _selectedLeft = null;
        _selectedRight = null;
      });
    } else {
      _wrongTaps++;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _selectedLeft = null;
          _selectedRight = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: buildGameAppBar(
        context,
        titleKey: 'games.word_match.title',
        icon: Icons.compare_arrows_rounded,
        actions: <Widget>[
          IconButton(
            tooltip: 'games.rules'.tr(),
            onPressed: () => showGameRulesDialog(
              context,
              titleKey: 'games.word_match.title',
              bodyKey: 'games.word_match.rules',
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
          IconButton(
            tooltip: 'common.retry'.tr(),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return GameErrorView(message: _error!, onRetry: _load);
    final WordMatchDto d = _data!;
    final bool done = _matched.length == d.pairs.length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GameHeader(
            level: d.level,
            topic: d.topicLabel,
            trailing: '${_matched.length}/${d.pairs.length}',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ListView.separated(
                    itemCount: _leftWords.length,
                    separatorBuilder: (BuildContext _, int i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext c, int i) {
                      final bool matched = _matched.contains(i);
                      final bool selected = _selectedLeft == i;
                      return _Tile(
                        text: _leftWords[i],
                        matched: matched,
                        selected: selected,
                        onTap: matched
                            ? null
                            : () {
                                setState(() => _selectedLeft = i);
                                _tryMatch();
                              },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _rightTranslations.length,
                    separatorBuilder: (BuildContext _, int i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext c, int i) {
                      final bool matched = _matched.contains(_rightToLeft[i]);
                      final bool selected = _selectedRight == i;
                      return _Tile(
                        text: _rightTranslations[_rightToLeft[i]],
                        matched: matched,
                        selected: selected,
                        onTap: matched
                            ? null
                            : () {
                                setState(() => _selectedRight = i);
                                _tryMatch();
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GameDoneBar(
                title: 'games.done'.tr(),
                subtitle: 'games.mistakes'.tr(
                  args: <String>[_wrongTaps.toString()],
                ),
                onReplay: _load,
                onClose: () => context.pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.text,
    required this.matched,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool matched;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color border = matched
        ? AppTheme.successGreen
        : selected
        ? primary
        : cs.outlineVariant;
    final Color bg = matched
        ? AppTheme.successGreen.withValues(alpha: 0.12)
        : selected
        ? primary.withValues(alpha: 0.10)
        : cs.surfaceContainerLowest;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
              width: selected || matched ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: matched || selected
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: matched
                  ? AppTheme.successGreen
                  : selected
                  ? primary
                  : null,
              decoration: matched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}
