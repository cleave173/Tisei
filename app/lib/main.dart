import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/character/character_notifier.dart';
import 'core/notifications/learning_reminder_notifier.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/utils/app_snack_bar.dart';
import 'core/utils/auth_event_bus.dart';
import 'features/auth/presentation/providers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    EasyLocalization(
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ru'),
        Locale('kk'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: <Override>[
          themeNotifierProvider.overrideWith((Ref ref) => ThemeNotifier(prefs)),
          characterNotifierProvider.overrideWith(
            (Ref ref) => CharacterNotifier(prefs),
          ),
          learningReminderProvider.overrideWith(
            (Ref ref) => LearningReminderNotifier(prefs),
          ),
        ],
        child: const TiseiApp(),
      ),
    ),
  );
}

class TiseiApp extends ConsumerStatefulWidget {
  const TiseiApp({super.key});

  @override
  ConsumerState<TiseiApp> createState() => _TiseiAppState();
}

class _TiseiAppState extends ConsumerState<TiseiApp> {
  StreamSubscription<void>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _sessionSub = AuthEventBus.onSessionExpired.listen((_) {
      ref.read(authControllerProvider.notifier).logout();
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeState themeState = ref.watch(themeNotifierProvider);
    final Color seed = themeState.palette.seed;
    return MaterialApp.router(
      title: 'Tisei',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppSnackBar.rootKey,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: themeState.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }
}
