import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../assessment/data/assessment_repository.dart';
import '../../../assessment/data/models/assessment_dto.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/learning_repository.dart';
import '../../data/models/learning_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final String name = auth is AuthAuthenticated ? auth.user.fullName.split(' ').first : 'friend';
    final int xp = auth is AuthAuthenticated ? (auth.user.profile?.experiencePoints ?? 0) : 0;
    final int level = auth is AuthAuthenticated ? (auth.user.profile?.level ?? 1) : 1;
    final String? cefrLevel = auth is AuthAuthenticated ? auth.user.profile?.cefrLevel : null;

    final AsyncValue<List<TopicDto>> topics = ref.watch(topicsProvider('en'));
    final AsyncValue<LevelStatusDto> statusAsync = ref.watch(levelStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text('home.title'.tr(args: <String>[name]))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topicsProvider('en'));
          ref.invalidate(levelStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _CurrentLanguageCard(
              language: 'English',
              cefrLevel: cefrLevel,
              level: level,
              xp: xp,
              onTap: () => context.push('/learning/en'),
            ),
            const SizedBox(height: 12),
            statusAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (Object err, StackTrace st) => const SizedBox.shrink(),
              data: (LevelStatusDto s) {
                if (!s.placementDone) {
                  return _AssessmentBanner(
                    icon: Icons.assignment_outlined,
                    message: 'assessment.placement_cta'.tr(),
                    onTap: () => context.push(Routes.placementTest),
                  );
                }
                if (s.canLevelUp && s.nextLevel != null) {
                  return _AssessmentBanner(
                    icon: Icons.trending_up_rounded,
                    message: 'assessment.level_up_cta'
                        .tr(args: <String>[s.nextLevel!]),
                    onTap: () => context.push(Routes.levelUpTest),
                  );
                }
                // Show topics-progress gate when level-up is locked.
                if (s.nextLevel != null) {
                  return topics.maybeWhen(
                    data: (List<TopicDto> ts) {
                      if (ts.isEmpty) return const SizedBox.shrink();
                      final int done = ts.where(
                        (TopicDto t) => t.lessonsCount > 0 &&
                            t.completedLessons >= t.lessonsCount,
                      ).length;
                      final int needed =
                          (ts.length * 0.5).ceil();
                      if (done >= needed) return const SizedBox.shrink();
                      return _TopicsGateBanner(
                        completedTopics: done,
                        totalTopics: ts.length,
                        neededTopics: needed,
                        nextLevel: s.nextLevel!,
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            _GamesEntryCard(onTap: () => context.push(Routes.games)),
            const SizedBox(height: 24),
            Text('home.available_courses'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            topics.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
              ),
              data: (List<TopicDto> ts) => Column(
                children: ts
                    .map((TopicDto t) => _TopicProgressCard(topic: t))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentBanner extends StatelessWidget {
  const _AssessmentBanner({
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLanguageCard extends StatelessWidget {
  const _CurrentLanguageCard({
    required this.language,
    required this.level,
    required this.xp,
    required this.onTap,
    this.cefrLevel,
  });

  final String language;
  final int level;
  final int xp;
  final VoidCallback onTap;
  final String? cefrLevel;

  @override
  Widget build(BuildContext context) {
    final double progress = ((xp % 100) / 100.0).clamp(0.0, 1.0);
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(language,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  if (cefrLevel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cefrLevel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Level $level · $xp XP', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicProgressCard extends StatelessWidget {
  const _TopicProgressCard({required this.topic});
  final TopicDto topic;

  @override
  Widget build(BuildContext context) {
    final int total = topic.lessonsCount;
    final int done = topic.completedLessons.clamp(0, total);
    final double progress = total > 0 ? done / total : 0.0;
    final bool finished = total > 0 && done >= total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/topic/${topic.id}', extra: topic),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        topic.localizedTitle(context.locale.languageCode),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        topic.level,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            finished ? AppTheme.successGreen : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      total > 0 ? '$done/$total' : '${topic.wordCount} words',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: finished ? AppTheme.successGreen : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GamesEntryCard extends StatelessWidget {
  const _GamesEntryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF7C4DFF), Color(0xFFE91E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.videogame_asset_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'home.games_title'.tr(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'home.games_subtitle'.tr(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topics gate banner — shown when level-up is locked by the 50 % rule
// ---------------------------------------------------------------------------

class _TopicsGateBanner extends StatelessWidget {
  const _TopicsGateBanner({
    required this.completedTopics,
    required this.totalTopics,
    required this.neededTopics,
    required this.nextLevel,
  });

  final int completedTopics;
  final int totalTopics;
  final int neededTopics;
  final String nextLevel;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final double progress =
        totalTopics > 0 ? completedTopics / totalTopics : 0.0;
    final int remaining = (neededTopics - completedTopics).clamp(0, totalTopics);

    return Material(
      color: primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, color: primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'assessment.level_up_locked'
                        .tr(args: <String>[nextLevel]),
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'assessment.complete_more_topics'
                  .tr(args: <String>['$remaining']),
              style: TextStyle(
                color: primary.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$completedTopics / $neededTopics',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

