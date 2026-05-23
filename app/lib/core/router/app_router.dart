import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessment/presentation/pages/level_up_test_page.dart';
import '../../features/assessment/presentation/pages/placement_test_page.dart';
import '../../features/achievements/presentation/pages/achievements_page.dart';
import '../../features/games/presentation/pages/games_hub_page.dart';
import '../../features/games/presentation/pages/hangman_page.dart';
import '../../features/games/presentation/pages/sentence_builder_page.dart';
import '../../features/games/presentation/pages/word_match_page.dart';
import '../../features/games/presentation/pages/word_scramble_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/starter_page.dart';
import '../../features/learning/data/models/learning_models.dart';
import '../../features/learning/presentation/pages/home_page.dart';
import '../../features/learning/presentation/pages/learning_page.dart';
import '../../features/learning/presentation/pages/topic_page.dart';
import '../../features/learning/presentation/pages/vocab_lesson_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/speaking/presentation/pages/speaking_quiz_page.dart';
import '../../features/translator/presentation/pages/translator_page.dart';
import '../widgets/main_scaffold.dart';

/// Top-level route names. Centralizing them avoids stringly-typed mistakes.
class Routes {
  static const String splash = '/';
  static const String starter = '/starter';
  static const String login = '/login';
  static const String register = '/register';

  static const String home = '/home';
  static const String search = '/search';
  static const String translator = '/translator';
  static const String achievements = '/achievements';
  static const String profile = '/profile';

  static const String settings = '/settings';
  static const String placementTest = '/placement-test';
  static const String levelUpTest = '/level-up-test';
  static const String games = '/games';
  static const String gameWordMatch = '/games/word-match';
  static const String gameWordScramble = '/games/word-scramble';
  static const String gameSentenceBuilder = '/games/sentence-builder';
  static const String gameHangman = '/games/hangman';
  static const String learning = '/learning/:languageCode';
  static const String topic = '/topic/:topicId';
  static const String vocabLesson = '/topic/:topicId/lesson/:lessonIndex';
  static const String speaking = '/speaking/:topicId';
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (BuildContext c, GoRouterState s) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.starter,
        builder: (BuildContext c, GoRouterState s) => const StarterPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (BuildContext c, GoRouterState s) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (BuildContext c, GoRouterState s) => const RegisterPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (BuildContext c, GoRouterState s) => const SettingsPage(),
      ),
      GoRoute(
        path: Routes.placementTest,
        builder: (BuildContext c, GoRouterState s) => const PlacementTestPage(),
      ),
      GoRoute(
        path: Routes.levelUpTest,
        builder: (BuildContext c, GoRouterState s) => const LevelUpTestPage(),
      ),
      GoRoute(
        path: Routes.games,
        builder: (BuildContext c, GoRouterState s) => const GamesHubPage(),
      ),
      GoRoute(
        path: Routes.gameWordMatch,
        builder: (BuildContext c, GoRouterState s) =>
            WordMatchPage(topic: s.extra is String ? s.extra as String : null),
      ),
      GoRoute(
        path: Routes.gameWordScramble,
        builder: (BuildContext c, GoRouterState s) =>
            WordScramblePage(topic: s.extra is String ? s.extra as String : null),
      ),
      GoRoute(
        path: Routes.gameSentenceBuilder,
        builder: (BuildContext c, GoRouterState s) =>
            SentenceBuilderPage(topic: s.extra is String ? s.extra as String : null),
      ),
      GoRoute(
        path: Routes.gameHangman,
        builder: (BuildContext c, GoRouterState s) =>
            HangmanPage(topic: s.extra is String ? s.extra as String : null),
      ),
      GoRoute(
        path: Routes.learning,
        builder: (BuildContext c, GoRouterState s) =>
            LearningPage(languageCode: s.pathParameters['languageCode']!),
      ),
      GoRoute(
        path: Routes.topic,
        builder: (BuildContext c, GoRouterState s) => TopicPage(
          topicId: int.parse(s.pathParameters['topicId']!),
          preloaded: s.extra is TopicDto ? s.extra! as TopicDto : null,
        ),
      ),
      GoRoute(
        path: Routes.vocabLesson,
        builder: (BuildContext c, GoRouterState s) => VocabLessonPage(
          topicId: int.parse(s.pathParameters['topicId']!),
          lessonIndex: int.parse(s.pathParameters['lessonIndex']!),
        ),
      ),
      GoRoute(
        path: Routes.speaking,
        builder: (BuildContext c, GoRouterState s) => SpeakingQuizPage(
          topicId: int.parse(s.pathParameters['topicId']!),
          level: s.uri.queryParameters['level'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext c,
              GoRouterState s,
              StatefulNavigationShell shell,
            ) => MainScaffold(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (BuildContext c, GoRouterState s) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.search,
                builder: (BuildContext c, GoRouterState s) =>
                    const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.translator,
                builder: (BuildContext c, GoRouterState s) =>
                    const TranslatorPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.achievements,
                builder: (BuildContext c, GoRouterState s) =>
                    const AchievementsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                builder: (BuildContext c, GoRouterState s) =>
                    const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
