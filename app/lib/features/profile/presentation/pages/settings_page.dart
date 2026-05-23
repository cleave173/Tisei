import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/character/character_notifier.dart';
import '../../../../core/character/character_scenario.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/theme_notifier.dart';

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
              }
            },
          ),

          // ── Dark mode ────────────────────────────────────────────────────
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text('settings.dark_mode'.tr()),
            value: isDark,
            onChanged: (bool val) => notifier.setThemeMode(
              val ? ThemeMode.dark : ThemeMode.light,
            ),
          ),

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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'character.title'.tr(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
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
                          color: p.seed.withValues(alpha: selected ? 0.55 : 0.28),
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
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
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
    final CharacterNotifier charNotifier =
        ref.read(characterNotifierProvider.notifier);
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
                errorBuilder: (_, __, ___) => _EmojiPreview(scenario: scenario),
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
              final XFile? file = await ImagePicker()
                  .pickImage(source: ImageSource.gallery);
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
        child: Text(scenario.defaultEmoji,
            style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
