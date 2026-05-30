import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Special token meaning "any CEFR level" — backend skips the level filter.
const String kAnyLevel = 'ANY';

const List<String> _kCefrLevels = <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Reads the current user's CEFR level from auth state, or null if unknown.
String? readUserCefrLevel(WidgetRef ref) {
  final AuthState s = ref.read(authControllerProvider);
  if (s is AuthAuthenticated) return s.user.profile?.cefrLevel;
  return null;
}

/// Localized human-readable label for a level value.
String levelLabel(String value) {
  if (value.toUpperCase() == kAnyLevel) return 'games.level_any'.tr();
  return value.toUpperCase();
}

AppBar buildGameAppBar(
  BuildContext context, {
  required String titleKey,
  required IconData icon,
  required List<Widget> actions,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            titleKey.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: actions,
  );
}

/// Shows a modal explaining the rules of a game.
/// `bodyKey` is the localization key for the rules body (e.g. `games.word_match.rules`).
Future<void> showGameRulesDialog(
  BuildContext context, {
  required String titleKey,
  required String bodyKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: Theme.of(c).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(titleKey.tr())),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          bodyKey.tr(),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text('common.ok'.tr()),
        ),
      ],
    ),
  );
}

/// Shows a level picker. Returns the chosen level (CEFR string or [kAnyLevel]),
/// or null if user cancelled.
Future<String?> showLevelPickerDialog(
  BuildContext context, {
  required String currentLevel,
  String? userLevel,
}) {
  return showDialog<String?>(
    context: context,
    builder: (BuildContext c) {
      return AlertDialog(
        title: Text('games.level_pick'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _LevelOption(
              value: kAnyLevel,
              currentValue: currentLevel,
              title: 'games.level_any'.tr(),
              subtitle: 'games.level_any_hint'.tr(),
              onPick: (String v) => Navigator.of(c).pop(v),
            ),
            if (userLevel != null &&
                _kCefrLevels.contains(userLevel.toUpperCase()))
              _LevelOption(
                value: userLevel.toUpperCase(),
                currentValue: currentLevel,
                title: 'games.level_my'.tr(
                  args: <String>[userLevel.toUpperCase()],
                ),
                subtitle: 'games.level_my_hint'.tr(),
                onPick: (String v) => Navigator.of(c).pop(v),
              ),
            const Divider(height: 16),
            Text(
              'games.level_explicit'.tr(),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Wrap(
              spacing: 6,
              children: _kCefrLevels
                  .map(
                    (String l) => ChoiceChip(
                      label: Text(l),
                      selected: currentLevel == l,
                      onSelected: (_) => Navigator.of(c).pop(l),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      );
    },
  );
}

class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.level, this.topic, this.trailing});
  final String level;
  final String? topic;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              levelLabel(level),
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (topic != null && topic!.isNotEmpty)
            Expanded(
              child: Text(
                topic!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class GameErrorView extends StatelessWidget {
  const GameErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const Color errorColor = Color(0xFFC62828);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: errorColor),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: errorColor),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class GameDoneBar extends StatelessWidget {
  const GameDoneBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onReplay,
    required this.onClose,
    this.success = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onReplay;
  final VoidCallback onClose;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final Color color = success ? AppTheme.successGreen : AppTheme.errorRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  child: Text('common.ok'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('games.play_again'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({
    required this.value,
    required this.currentValue,
    required this.title,
    required this.subtitle,
    required this.onPick,
  });

  final String value;
  final String currentValue;
  final String title;
  final String subtitle;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == currentValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.black45,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () => onPick(value),
    );
  }
}
