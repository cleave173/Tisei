import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _GameInfo {
  const _GameInfo({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.route,
  });
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final String route;
}

const List<_GameInfo> _games = <_GameInfo>[
  _GameInfo(
    titleKey: 'games.word_match.title',
    subtitleKey: 'games.word_match.subtitle',
    icon: Icons.compare_arrows_rounded,
    gradientStart: Color(0xFF1565C0),
    gradientEnd: Color(0xFF42A5F5),
    route: Routes.gameWordMatch,
  ),
  _GameInfo(
    titleKey: 'games.word_scramble.title',
    subtitleKey: 'games.word_scramble.subtitle',
    icon: Icons.sort_by_alpha_rounded,
    gradientStart: Color(0xFFE65100),
    gradientEnd: Color(0xFFFFB74D),
    route: Routes.gameWordScramble,
  ),
  _GameInfo(
    titleKey: 'games.sentence_builder.title',
    subtitleKey: 'games.sentence_builder.subtitle',
    icon: Icons.reorder_rounded,
    gradientStart: Color(0xFF2E7D32),
    gradientEnd: Color(0xFF66BB6A),
    route: Routes.gameSentenceBuilder,
  ),
  _GameInfo(
    titleKey: 'games.hangman.title',
    subtitleKey: 'games.hangman.subtitle',
    icon: Icons.spellcheck_rounded,
    gradientStart: Color(0xFF6A1B9A),
    gradientEnd: Color(0xFFBA68C8),
    route: Routes.gameHangman,
  ),
];

// ── Page ──────────────────────────────────────────────────────────────────────

class GamesHubPage extends ConsumerWidget {
  const GamesHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('games.title'.tr())),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
        ),
        itemCount: _games.length,
        itemBuilder: (BuildContext ctx, int i) {
          final _GameInfo g = _games[i];
          return _GameCard(
            game: g,
            onTap: () => _pickModeAndGo(context, g.route),
          );
        },
      ),
    );
  }

  Future<void> _pickModeAndGo(BuildContext context, String route) async {
    final Map<String, String>? result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext c) => const _ModeSheet(),
    );
    if (result == null) return;
    if (!context.mounted) return;
    context.push(route, extra: result);
  }
}

// ── Game card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final _GameInfo game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[game.gradientStart, game.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: game.gradientStart.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(game.icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Text(
                  game.titleKey.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.subtitleKey.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSheet extends StatefulWidget {
  const _ModeSheet();

  @override
  State<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends State<_ModeSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _aiSelected = false;
  String? _translationLang;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _translationLang ??= context.locale.languageCode == 'kk' ? 'kk' : 'ru';
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'games.choose_mode'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            'games.custom_topic_hint'.tr(),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Mode tiles
          Row(
            children: <Widget>[
              Expanded(
                child: _ModeTile(
                  icon: Icons.tune_rounded,
                  label: 'games.default_mode'.tr(),
                  selected: !_aiSelected,
                  onTap: () => setState(() => _aiSelected = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'games.ai_mode'.tr(),
                  selected: _aiSelected,
                  isAi: true,
                  onTap: () => setState(() => _aiSelected = true),
                ),
              ),
            ],
          ),

          // Topic field (AI only)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _aiSelected
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'games.topic_placeholder'.tr(),
                        prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (String v) {
                        if (v.trim().isNotEmpty) {
                          Navigator.of(context).pop(<String, String>{
                            'topic': v.trim(),
                            'translationLang': _translationLang!,
                          });
                        }
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Translation Language selector
          const SizedBox(height: 20),
          Text(
            'games.translation_language'.tr(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _LanguageTile(
                  label: 'Русский',
                  selected: _translationLang == 'ru',
                  onTap: () => setState(() => _translationLang = 'ru'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LanguageTile(
                  label: 'Қазақша',
                  selected: _translationLang == 'kk',
                  onTap: () => setState(() => _translationLang = 'kk'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action button
          FilledButton(
            onPressed: () {
              if (_aiSelected) {
                final String t = _ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.of(context).pop(<String, String>{
                  'topic': t,
                  'translationLang': _translationLang!,
                });
              } else {
                Navigator.of(context).pop(<String, String>{
                  'topic': '',
                  'translationLang': _translationLang!,
                });
              }
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'common.start'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAi = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool isAi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected && isAi
              ? LinearGradient(
                  colors: <Color>[cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected && !isAi
              ? cs.primaryContainer
              : !selected
                  ? cs.surfaceContainerHighest
                  : null,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: Colors.transparent)
              : Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected
                  ? (isAi ? Colors.white : cs.onPrimaryContainer)
                  : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? (isAi ? Colors.white : cs.onPrimaryContainer)
                      : cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: cs.primary, width: 1.5)
              : Border.all(color: cs.outlineVariant),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
