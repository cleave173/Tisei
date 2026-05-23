import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

final FutureProvider<List<dynamic>> _achievementsProvider = FutureProvider<List<dynamic>>(
  (Ref ref) async {
    final dynamic data = await ref.read(apiClientProvider).get('/achievements');
    return data as List<dynamic>;
  },
);

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<dynamic>> data = ref.watch(_achievementsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('achievements.title'.tr())),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<dynamic> list) {
          if (list.isEmpty) {
            return Center(child: Text('achievements.placeholder'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext c, int i) {
              final Map<String, dynamic> a = Map<String, dynamic>.from(list[i] as Map);
              final int progress = (a['progress'] as int?) ?? 0;
              final int req = (a['requirement_value'] as int?) ?? 1;
              final double frac = (progress / req).clamp(0.0, 1.0);
              final bool unlocked = (a['unlocked'] as bool?) ?? false;
              final int stars = (a['stars'] as int?) ?? 1;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        unlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
                        color: unlocked ? Theme.of(context).colorScheme.primary : Colors.black26,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    a['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Row(
                                  children: List<Widget>.generate(
                                    stars,
                                    (int i) => const Icon(Icons.star, size: 14, color: Colors.amber),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (a['description'] as String?) ?? '',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: frac, minHeight: 6),
                            ),
                            const SizedBox(height: 4),
                            Text('$progress / $req',
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
