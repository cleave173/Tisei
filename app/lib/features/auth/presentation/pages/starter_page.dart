import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

class StarterPage extends StatelessWidget {
  const StarterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 18),
              const _StarterLanguagePicker(),
              const Spacer(),
              Icon(Icons.translate, size: 96, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'app.name'.tr(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'app.tagline'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.push(Routes.register),
                child: Text('auth.register'.tr()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push(Routes.login),
                child: Text('auth.login'.tr()),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterLanguagePicker extends StatelessWidget {
  const _StarterLanguagePicker();

  static const List<(Locale, String)> _languages = <(Locale, String)>[
    (Locale('ru'), 'Русский'),
    (Locale('kk'), 'Қазақша'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String selected = context.locale.languageCode;
    if (selected != 'ru' && selected != 'kk') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.setLocale(const Locale('ru'));
        }
      });
    }
    final String activeLanguage = selected == 'kk' ? 'kk' : 'ru';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _languages.map(((Locale, String) item) {
          final Locale locale = item.$1;
          final String label = item.$2;
          final bool active = activeLanguage == locale.languageCode;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.setLocale(locale),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: active ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: active ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
