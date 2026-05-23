import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/learning_models.dart';
import '../../data/models/vocab_lesson_models.dart';
import '../../data/vocab_lesson_repository.dart';

/// Topic detail — a list of vocab lessons.
/// Each lesson is a chunk of words inside the topic. Tapping a lesson opens
/// the multi-stage VocabLessonPage (cards → listening → MC → speaking).
class TopicPage extends ConsumerWidget {
  const TopicPage({super.key, required this.topicId, this.preloaded});
  final int topicId;
  final TopicDto? preloaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String fallbackTitle =
        preloaded?.localizedTitle(context.locale.languageCode) ?? 'learning.introduction'.tr();
    final AsyncValue<VocabLessonsListDto> data =
        ref.watch(vocabLessonsByTopicProvider(topicId));

    return Scaffold(
      appBar: AppBar(
        title: Text(data.maybeWhen(
          data: (VocabLessonsListDto d) => d.topicTitle,
          orElse: () => fallbackTitle,
        )),
        actions: <Widget>[
          if (preloaded != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _LevelBadge(level: preloaded!.level),
              ),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (VocabLessonsListDto d) {
          if (d.lessons.isEmpty) {
            return Center(child: Text('learning.no_lessons'.tr()));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vocabLessonsByTopicProvider(topicId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: d.lessons.length,
              separatorBuilder: (BuildContext ctx, int index) => const SizedBox(height: 12),
              itemBuilder: (BuildContext c, int i) => _LessonTile(
                topicId: d.topicId,
                lesson: d.lessons[i],
                lessonNumber: i + 1,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.topicId,
    required this.lesson,
    required this.lessonNumber,
  });

  final int topicId;
  final VocabLessonDto lesson;
  final int lessonNumber;

  @override
  Widget build(BuildContext context) {
    final VocabProgressDto p = lesson.progress;
    final List<bool> stages = <bool>[
      p.cardsDone,
      p.listeningDone,
      p.mcDone,
      p.speakingDone,
    ];
    final int done = stages.where((bool x) => x).length;
    final bool completed = p.isCompleted;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/topic/$topicId/lesson/${lesson.index}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: completed ? AppTheme.successGreen : Theme.of(context).colorScheme.primary,
                child: completed
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text(
                        '$lessonNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'learning.lesson_n'.tr(args: <String>['$lessonNumber']),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'learning.lesson_subtitle'.tr(args: <String>[
                        '${lesson.words.length}',
                        '$done',
                        '${stages.length}',
                      ]),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        _StageDot(label: 'C', done: p.cardsDone, color: Theme.of(context).colorScheme.primary),
                        _StageDot(label: 'L', done: p.listeningDone, color: Colors.deepPurple),
                        _StageDot(label: 'T', done: p.mcDone, color: Colors.orange),
                        _StageDot(label: 'S', done: p.speakingDone, color: Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.label, required this.done, required this.color});
  final String label;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.transparent,
          border: Border.all(color: done ? color : Colors.black26, width: 1.5),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                ),
              ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
