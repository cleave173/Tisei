import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../data/games_repository.dart';
import '../../data/models/game_dtos.dart';
import '../widgets/game_widgets.dart';

class HangmanPage extends ConsumerStatefulWidget {
  const HangmanPage({super.key, this.topic});
  final String? topic;

  @override
  ConsumerState<HangmanPage> createState() => _HangmanPageState();
}

class _HangmanPageState extends ConsumerState<HangmanPage> {
  static const int _maxMistakes = 6;
  static const List<String> _alphabet = <String>[
    'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
  ];

  HangmanDto? _data;
  String? _error;
  bool _loading = true;
  String _level = kAnyLevel;

  final Set<String> _guessed = <String>{};
  int _mistakes = 0;

  @override
  void initState() {
    super.initState();
    final String? userLevel = readUserCefrLevel(ref);
    if (userLevel != null && userLevel.isNotEmpty) _level = userLevel.toUpperCase();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _guessed.clear();
      _mistakes = 0;
    });
    try {
      final HangmanDto d = await ref
          .read(gamesRepositoryProvider)
          .generateHangman(topic: widget.topic, level: _level);
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

  bool get _isWin {
    if (_data == null) return false;
    return _data!.word.split('').every((c) =>
        !RegExp(r'[a-z]').hasMatch(c) || _guessed.contains(c));
  }

  bool get _isLose => _mistakes >= _maxMistakes;

  void _guess(String letter) {
    if (_isWin || _isLose) return;
    if (_guessed.contains(letter)) return;
    setState(() {
      _guessed.add(letter);
      if (!_data!.word.contains(letter)) _mistakes++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('games.hangman.title'.tr()),
        actions: <Widget>[
          IconButton(
            tooltip: 'games.rules'.tr(),
            onPressed: () => showGameRulesDialog(
              context,
              titleKey: 'games.hangman.title',
              bodyKey: 'games.hangman.rules',
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
    final HangmanDto d = _data!;
    final bool finished = _isWin || _isLose;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GameHeader(
            level: d.level,
            topic: d.topicLabel,
            trailing: '$_mistakes/$_maxMistakes',
          ),
          const SizedBox(height: 12),
          Text(
            'games.hangman.hint'.tr(args: <String>[d.hint]),
            style: const TextStyle(fontSize: 15, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _HangmanGallows(mistakes: _mistakes, max: _maxMistakes),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: d.word.split('').map((String c) {
                final bool isLetter = RegExp(r'[a-z]').hasMatch(c);
                final bool shown = !isLetter || _guessed.contains(c) || _isLose;
                return Container(
                  width: 28,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isLetter ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    shown ? c.toUpperCase() : '',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _isLose && !_guessed.contains(c) && isLetter
                          ? AppTheme.errorRed
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (!finished)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _alphabet.map((String l) {
                final bool used = _guessed.contains(l);
                final bool right = used && d.word.contains(l);
                return SizedBox(
                  width: 36,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: used ? null : () => _guess(l),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 40),
                      foregroundColor: used
                          ? (right ? AppTheme.successGreen : AppTheme.errorRed)
                          : null,
                    ),
                    child: Text(
                      l.toUpperCase(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }).toList(),
            ),
          const Spacer(),
          if (finished)
            GameDoneBar(
              success: _isWin,
              title: _isWin ? 'games.hangman.win'.tr() : 'games.hangman.lose'.tr(),
              subtitle: _isWin
                  ? 'games.hangman.translation_was'
                      .tr(args: <String>[d.translation])
                  : 'games.hangman.word_was'
                      .tr(args: <String>[d.word.toUpperCase(), d.translation]),
              onReplay: _load,
              onClose: () => context.pop(),
            ),
        ],
      ),
    );
  }
}

/// Simple geometric gallows that fills in progressively as `mistakes` grows.
class _HangmanGallows extends StatelessWidget {
  const _HangmanGallows({required this.mistakes, required this.max});
  final int mistakes;
  final int max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _GallowsPainter(mistakes: mistakes),
        size: const Size(160, 140),
      ),
    );
  }
}

class _GallowsPainter extends CustomPainter {
  _GallowsPainter({required this.mistakes});
  final int mistakes;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // Always draw gallows scaffolding
    // base
    canvas.drawLine(Offset(cx - 50, h - 4), Offset(cx + 50, h - 4), p);
    // pole
    canvas.drawLine(Offset(cx - 30, h - 4), Offset(cx - 30, 10), p);
    // top
    canvas.drawLine(Offset(cx - 30, 10), Offset(cx + 30, 10), p);
    // rope
    canvas.drawLine(Offset(cx + 30, 10), Offset(cx + 30, 30), p);

    if (mistakes >= 1) {
      canvas.drawCircle(Offset(cx + 30, 42), 12, p); // head
    }
    if (mistakes >= 2) {
      canvas.drawLine(Offset(cx + 30, 54), Offset(cx + 30, 90), p); // body
    }
    if (mistakes >= 3) {
      canvas.drawLine(Offset(cx + 30, 62), Offset(cx + 14, 78), p); // L arm
    }
    if (mistakes >= 4) {
      canvas.drawLine(Offset(cx + 30, 62), Offset(cx + 46, 78), p); // R arm
    }
    if (mistakes >= 5) {
      canvas.drawLine(Offset(cx + 30, 90), Offset(cx + 16, 110), p); // L leg
    }
    if (mistakes >= 6) {
      canvas.drawLine(Offset(cx + 30, 90), Offset(cx + 44, 110), p); // R leg
    }
  }

  @override
  bool shouldRepaint(covariant _GallowsPainter oldDelegate) =>
      oldDelegate.mistakes != mistakes;
}
