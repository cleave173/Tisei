import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snack_bar.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AchievementDto {
  const AchievementDto({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.stars,
    required this.requirementValue,
    required this.progress,
    required this.unlocked,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final int stars;
  final int requirementValue;
  final int progress;
  final bool unlocked;

  double get fraction =>
      requirementValue > 0 ? (progress / requirementValue).clamp(0.0, 1.0) : 0.0;

  factory AchievementDto.fromJson(Map<String, dynamic> j) => AchievementDto(
        id: j['id'] as int,
        code: j['code'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        stars: (j['stars'] as int?) ?? 1,
        requirementValue: (j['requirement_value'] as int?) ?? 1,
        progress: (j['progress'] as int?) ?? 0,
        unlocked: (j['unlocked'] as bool?) ?? false,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final AutoDisposeFutureProvider<List<AchievementDto>> achievementsProvider =
    FutureProvider.autoDispose<List<AchievementDto>>((Ref ref) async {
  final dynamic raw = await ref.read(apiClientProvider).get('/achievements');
  return (raw as List<dynamic>)
      .map((dynamic e) => AchievementDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AchievementDto>> data = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('achievements.title'.tr()),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Tab>[
            Tab(text: 'achievements.tab_all'.tr()),
            Tab(text: 'achievements.tab_unlocked'.tr()),
            Tab(text: 'achievements.tab_progress'.tr()),
          ],
        ),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFC62828)),
              const SizedBox(height: 12),
              Text(AppSnackBar.friendlyMessage(e), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(achievementsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (List<AchievementDto> all) {
          final List<AchievementDto> unlocked = all.where((AchievementDto a) => a.unlocked).toList();
          final List<AchievementDto> inProgress = all
              .where((AchievementDto a) => !a.unlocked && a.progress > 0)
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(achievementsProvider),
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _AchievementList(items: all),
                _AchievementList(items: unlocked, emptyKey: 'achievements.none_unlocked'),
                _AchievementList(items: inProgress, emptyKey: 'achievements.none_in_progress'),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _AchievementList extends StatelessWidget {
  const _AchievementList({required this.items, this.emptyKey});
  final List<AchievementDto> items;
  final String? emptyKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyKey != null ? emptyKey!.tr() : 'achievements.placeholder'.tr(),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext ctx, int i) => _AchievementCard(item: items[i]),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item});
  final AchievementDto item;

  static const Map<String, IconData> _icons = <String, IconData>{
    'first_lesson': Icons.school_rounded,
    'studious_10': Icons.menu_book_rounded,
    'studious_50': Icons.auto_stories_rounded,
    'quickie': Icons.bolt_rounded,
    'ambitious': Icons.fitness_center_rounded,
    'streak_7': Icons.local_fire_department_rounded,
    'streak_30': Icons.local_fire_department_rounded,
    'vocab_100': Icons.library_books_rounded,
    'translator_50': Icons.translate_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool unlocked = item.unlocked;
    final IconData icon = _icons[item.code] ?? Icons.emoji_events_rounded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: unlocked
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon,
                  size: 26,
                  color: unlocked ? cs.onPrimaryContainer : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: unlocked ? null : cs.onSurfaceVariant,
                            )),
                      ),
                      if (unlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('achievements.unlocked'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        )
                      else
                        Row(
                          children: List<Widget>.generate(item.stars,
                              (_) => const Icon(Icons.star_rounded, size: 13, color: Colors.amber)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.description,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.fraction,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: unlocked ? const Color(0xFF2E7D32) : cs.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${item.progress} / ${item.requirementValue}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
