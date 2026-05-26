import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/learning_repository.dart';
import '../../data/models/learning_models.dart';

class LearningPage extends ConsumerWidget {
  const LearningPage({super.key, required this.languageCode});
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TopicDto>> topics = ref.watch(topicsProvider(languageCode));
    return Scaffold(
      appBar: AppBar(title: Text(languageCode.toUpperCase())),
      body: topics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<TopicDto> ts) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(topicsProvider(languageCode)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext c, int i) {
              final TopicDto t = ts[i];
              return Card(
                child: ListTile(
                  title: Text(t.localizedTitle(context.locale.languageCode)),
                  subtitle: Text('learning.level_word_count'.tr(args: <String>[t.level, '${t.wordCount}'])),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/topic/${t.id}', extra: t),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

