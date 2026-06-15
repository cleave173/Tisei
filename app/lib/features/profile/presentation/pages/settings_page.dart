import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/character/character_notifier.dart';
import '../../../../core/character/character_scenario.dart';
import '../../../../core/notifications/learning_reminder_notifier.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/theme_notifier.dart';
import '../../../../core/utils/app_snack_bar.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const Map<String, String> _langNames = <String, String>{
    'en': 'English',
    'ru': 'Русский',
    'kk': 'Қазақша',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeState themeState = ref.watch(themeNotifierProvider);
    final ThemeNotifier notifier = ref.read(themeNotifierProvider.notifier);
    final bool isDark = switch (themeState.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        children: <Widget>[
          // ── Language ────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('settings.app_language'.tr()),
            subtitle: Text(
              _langNames[context.locale.languageCode] ??
                  context.locale.toString(),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final Locale? picked = await showDialog<Locale>(
                context: context,
                builder: (BuildContext c) => SimpleDialog(
                  title: Text('settings.app_language'.tr()),
                  children: context.supportedLocales
                      .map(
                        (Locale l) => SimpleDialogOption(
                          onPressed: () => Navigator.of(c).pop(l),
                          child: Text(
                            _langNames[l.languageCode] ?? l.toString(),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
              if (picked != null && context.mounted) {
                await context.setLocale(picked);
                final LearningReminderState reminder = ref.read(
                  learningReminderProvider,
                );
                if (reminder.enabled && context.mounted) {
                  await ref
                      .read(learningReminderProvider.notifier)
                      .setTime(
                        time: TimeOfDay(
                          hour: reminder.hour,
                          minute: reminder.minute,
                        ),
                        title: 'settings.reminder_notification_title'.tr(),
                        body: 'settings.reminder_notification_body'.tr(),
                      );
                }
              }
            },
          ),

          // ── Dark mode ────────────────────────────────────────────────────
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text('settings.dark_mode'.tr()),
            value: isDark,
            onChanged: (bool val) =>
                notifier.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
          ),

          const _LearningReminderCard(),

          // ── Color palette ────────────────────────────────────────────────
          ListTile(
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: themeState.palette.seed,
            ),
            title: Text('settings.color_palette'.tr()),
            subtitle: Text(themeState.palette.nameKey.tr()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _PalettePickerDialog(
                selectedIndex: themeState.paletteIndex,
                onSelected: (int i) => notifier.setPalette(i),
              ),
            ),
          ),

          // ── Character ────────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'character.title'.tr(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'character.upload_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          for (final CharacterScenario s in CharacterScenario.values)
            _CharacterScenarioTile(scenario: s),
        ],
      ),
    );
  }
}

class _LearningReminderCard extends ConsumerWidget {
  const _LearningReminderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearningReminderState reminder = ref.watch(learningReminderProvider);
    final LearningReminderNotifier notifier = ref.read(
      learningReminderProvider.notifier,
    );
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String timeLabel = localizations.formatTimeOfDay(
      TimeOfDay(hour: reminder.hour, minute: reminder.minute),
      alwaysUse24HourFormat: true,
    );

    Future<void> toggleReminder(bool enabled) async {
      final bool ok = await notifier.setEnabled(
        enabled: enabled,
        title: 'settings.reminder_notification_title'.tr(),
        body: 'settings.reminder_notification_body'.tr(),
      );
      if (!context.mounted) return;
      if (ok) {
        AppSnackBar.showSuccess(
          context,
          enabled
              ? 'settings.reminder_enabled_message'.tr(
                  args: <String>[timeLabel],
                )
              : 'settings.reminder_disabled_message'.tr(),
        );
      } else {
        AppSnackBar.showWarning(
          context,
          'settings.reminder_permission_denied'.tr(),
        );
      }
    }

    Future<void> pickTime() async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (picked == null) return;
      final bool ok = await notifier.setTime(
        time: picked,
        title: 'settings.reminder_notification_title'.tr(),
        body: 'settings.reminder_notification_body'.tr(),
      );
      if (!context.mounted) return;
      AppSnackBar.showInfo(
        context,
        ok
            ? 'settings.reminder_time_saved'.tr(
                args: <String>[
                  localizations.formatTimeOfDay(
                    picked,
                    alwaysUse24HourFormat: true,
                  ),
                ],
              )
            : 'errors.server_error'.tr(),
      );
    }

    Future<void> showPreview() async {
      final bool ok = await notifier.showPreview(
        title: 'settings.reminder_notification_title'.tr(),
        body: 'settings.reminder_notification_body'.tr(),
      );
      if (!context.mounted) return;
      AppSnackBar.showInfo(
        context,
        ok
            ? 'settings.reminder_preview_sent'.tr()
            : 'settings.reminder_permission_denied'.tr(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'settings.learning_reminders'.tr(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'settings.learning_reminders_subtitle'.tr(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: reminder.enabled,
                    onChanged: reminder.isBusy ? null : toggleReminder,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ReminderPillButton(
                      icon: Icons.schedule_rounded,
                      label: 'settings.reminder_time'.tr(),
                      value: timeLabel,
                      onTap: pickTime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'settings.reminder_preview'.tr(),
                    onPressed: reminder.isBusy ? null : showPreview,
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderPillButton extends StatelessWidget {
  const _ReminderPillButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette picker dialog
// ---------------------------------------------------------------------------

class _PalettePickerDialog extends StatefulWidget {
  const _PalettePickerDialog({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final void Function(int) onSelected;

  @override
  State<_PalettePickerDialog> createState() => _PalettePickerDialogState();
}

class _PalettePickerDialogState extends State<_PalettePickerDialog> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('settings.color_palette'.tr()),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: kAppPalettes.length,
          itemBuilder: (BuildContext context, int index) {
            final AppPalette p = kAppPalettes[index];
            final bool selected = index == _current;
            return GestureDetector(
              onTap: () {
                setState(() => _current = index);
                widget.onSelected(index);
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.seed,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 3,
                            )
                          : null,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: p.seed.withValues(
                            alpha: selected ? 0.55 : 0.28,
                          ),
                          blurRadius: selected ? 14 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 26,
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.nameKey.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Character scenario tile
// ---------------------------------------------------------------------------

class _CharacterScenarioTile extends ConsumerWidget {
  const _CharacterScenarioTile({required this.scenario});
  final CharacterScenario scenario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CharacterState charState = ref.watch(characterNotifierProvider);
    final CharacterNotifier charNotifier = ref.read(
      characterNotifierProvider.notifier,
    );
    final String? imagePath = charState.imagePathFor(scenario);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imagePath != null
            ? Image.file(
                File(imagePath),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => _EmojiPreview(scenario: scenario),
              )
            : _EmojiPreview(scenario: scenario),
      ),
      title: Text(scenario.nameKey.tr()),
      subtitle: Text(
        imagePath != null
            ? 'character.custom_image'.tr()
            : 'character.default_label'.tr(),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: 'character.upload'.tr(),
            onPressed: () async {
              final XFile? file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) {
                await charNotifier.setImage(scenario, file.path);
              }
            },
          ),
          if (imagePath != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'character.remove'.tr(),
              onPressed: () => charNotifier.removeImage(scenario),
            ),
        ],
      ),
    );
  }
}

class _EmojiPreview extends StatelessWidget {
  const _EmojiPreview({required this.scenario});
  final CharacterScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          scenario.defaultEmoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
