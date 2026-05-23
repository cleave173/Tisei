import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/character/character_notifier.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../../core/character/character_overlay.dart';
import '../../../../core/character/character_scenario.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/learning_repository.dart';
import '../../data/models/vocab_lesson_models.dart';
import '../../data/vocab_lesson_repository.dart';
import '../widgets/cards_stage.dart';
import '../widgets/listening_stage.dart';
import '../widgets/mc_stage.dart';
import '../widgets/speaking_stage.dart';

/// Multi-stage vocab lesson: review cards → 3 tests (listening, MC, speaking).
///
/// Layout:
///   - Overview tab list with 4 cards (one per stage). The cards stage is
///     always unlocked. Tests are locked until `cards_done` is true.
///   - Tapping a stage pushes a sub-route within the same page that hosts the
///     respective stage widget. A back arrow always returns to the overview
///     (= "exit to vocabulary").
class VocabLessonPage extends ConsumerStatefulWidget {
  const VocabLessonPage({
    super.key,
    required this.topicId,
    required this.lessonIndex,
  });

  final int topicId;
  final int lessonIndex;

  @override
  ConsumerState<VocabLessonPage> createState() => _VocabLessonPageState();
}

class _VocabLessonPageState extends ConsumerState<VocabLessonPage> {
  VocabStage? _activeStage;

  VocabLessonKey get _key =>
      VocabLessonKey(topicId: widget.topicId, lessonIndex: widget.lessonIndex);

  /// Returns true if marking [s] will complete the entire lesson
  /// (i.e. all 4 stages will be done afterward).
  bool _willComplete(VocabProgressDto p, VocabStage s) =>
      (p.cardsDone || s == VocabStage.cards) &&
      (p.listeningDone || s == VocabStage.listening) &&
      (p.mcDone || s == VocabStage.mc) &&
      (p.speakingDone || s == VocabStage.speaking);

  Future<void> _markStage(VocabStage s) async {
    // Snapshot progress BEFORE the network call to detect lesson completion.
    final VocabProgressDto? currentProgress =
        ref.read(vocabLessonProvider(_key)).value?.progress;
    final bool willComplete = currentProgress != null &&
        !currentProgress.isCompleted &&
        _willComplete(currentProgress, s);

    try {
      final VocabStageResultDto res = await ref
          .read(vocabLessonRepositoryProvider)
          .markStage(topicId: widget.topicId, lessonIndex: widget.lessonIndex, stage: s);
      // Refresh data so the overview shows the new ✓.
      ref.invalidate(vocabLessonProvider(_key));
      ref.invalidate(vocabLessonsByTopicProvider(widget.topicId));
      // Refresh home page topic list (completed_lessons counter).
      ref.invalidate(topicsProvider('en'));
      // Refresh profile XP.
      await ref.read(authControllerProvider.notifier).refresh();
      if (!mounted) return;
      // Return to the lesson overview so the user sees the new ✓ and can pick the next stage.
      setState(() => _activeStage = null);
      if (res.xpEarnedNow > 0) {
        AppSnackBar.showSuccess(
          context,
          'lesson.xp_earned'.tr(args: <String>['${res.xpEarnedNow}']),
        );
      }
      // Show character overlay when all 4 stages are completed.
      if (willComplete && mounted) {
        final String? imgPath = ref
            .read(characterNotifierProvider)
            .imagePathFor(CharacterScenario.lessonCompleted);
        showCharacterOverlay(
          context,
          scenario: CharacterScenario.lessonCompleted,
          imagePath: imgPath,
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  void _exitStage() => setState(() => _activeStage = null);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VocabLessonDto> data = ref.watch(vocabLessonProvider(_key));

    return PopScope(
      // While inside a stage, back-button returns to overview instead of leaving the page.
      canPop: _activeStage == null,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop && _activeStage != null) _exitStage();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_activeStage == null
              ? 'lesson.title_n'.tr(args: <String>['${widget.lessonIndex + 1}'])
              : _stageTitle(_activeStage!)),
          leading: _activeStage != null
              ? IconButton(
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: 'lesson.exit_to_overview'.tr(),
                  onPressed: _exitStage,
                )
              : null,
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('$e')),
          data: (VocabLessonDto lesson) {
            if (_activeStage == null) {
              return _Overview(
                lesson: lesson,
                onOpenStage: (VocabStage s) => setState(() => _activeStage = s),
              );
            }
            return _StageHost(
              stage: _activeStage!,
              lesson: lesson,
              onCompleted: () => _markStage(_activeStage!),
            );
          },
        ),
      ),
    );
  }

  String _stageTitle(VocabStage s) => switch (s) {
        VocabStage.cards => 'lesson.stage_cards'.tr(),
        VocabStage.listening => 'lesson.stage_listening'.tr(),
        VocabStage.mc => 'lesson.stage_mc'.tr(),
        VocabStage.speaking => 'lesson.stage_speaking'.tr(),
      };
}

// ---------------------------------------------------------------------------
// Overview (stage picker)
// ---------------------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview({required this.lesson, required this.onOpenStage});
  final VocabLessonDto lesson;
  final void Function(VocabStage) onOpenStage;

  @override
  Widget build(BuildContext context) {
    final VocabProgressDto p = lesson.progress;
    final bool unlocked = p.testsUnlocked;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        _HeaderCard(lesson: lesson),
        const SizedBox(height: 18),
        _StageTile(
          title: 'lesson.stage_cards'.tr(),
          subtitle: 'lesson.stage_cards_sub'.tr(args: <String>['${lesson.words.length}']),
          icon: Icons.menu_book_rounded,
          color: Theme.of(context).colorScheme.primary,
          done: p.cardsDone,
          locked: false,
          onTap: () => onOpenStage(VocabStage.cards),
        ),
        const SizedBox(height: 10),
        _StageTile(
          title: 'lesson.stage_listening'.tr(),
          subtitle: 'lesson.stage_listening_sub'.tr(),
          icon: Icons.hearing_rounded,
          color: Colors.deepPurple,
          done: p.listeningDone,
          locked: !unlocked,
          onTap: () => onOpenStage(VocabStage.listening),
        ),
        const SizedBox(height: 10),
        _StageTile(
          title: 'lesson.stage_mc'.tr(),
          subtitle: 'lesson.stage_mc_sub'.tr(),
          icon: Icons.quiz_outlined,
          color: Colors.orange,
          done: p.mcDone,
          locked: !unlocked,
          onTap: () => onOpenStage(VocabStage.mc),
        ),
        const SizedBox(height: 10),
        _StageTile(
          title: 'lesson.stage_speaking'.tr(),
          subtitle: 'lesson.stage_speaking_sub'.tr(),
          icon: Icons.mic_rounded,
          color: Colors.teal,
          done: p.speakingDone,
          locked: !unlocked,
          onTap: () => onOpenStage(VocabStage.speaking),
        ),
        if (!unlocked) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.lock_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'lesson.tests_locked_hint'.tr(),
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (p.isCompleted) ...<Widget>[
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded,
                      color: AppTheme.successGreen, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'lesson.completed_badge'.tr(args: <String>['${p.xpEarned}']),
                    style: const TextStyle(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.lesson});
  final VocabLessonDto lesson;

  @override
  Widget build(BuildContext context) {
    final int done = <bool>[
      lesson.progress.cardsDone,
      lesson.progress.listeningDone,
      lesson.progress.mcDone,
      lesson.progress.speakingDone,
    ].where((bool x) => x).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'lesson.header_title'.tr(args: <String>['${lesson.index + 1}']),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'lesson.header_subtitle'.tr(args: <String>['${lesson.words.length}']),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: done / 4,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text('$done / 4 ${'lesson.stages_label'.tr()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.done,
    required this.locked,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool done;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done ? AppTheme.successGreen.withValues(alpha: 0.6) : Colors.black12,
              width: done ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (locked ? Colors.grey : color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: locked ? Colors.grey : color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: locked ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: locked ? Colors.grey : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (done)
                const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen)
              else if (locked)
                const Icon(Icons.lock_rounded, color: Colors.grey)
              else
                const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage host — dispatches to the active stage widget.
// ---------------------------------------------------------------------------

class _StageHost extends StatelessWidget {
  const _StageHost({
    required this.stage,
    required this.lesson,
    required this.onCompleted,
  });
  final VocabStage stage;
  final VocabLessonDto lesson;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    switch (stage) {
      case VocabStage.cards:
        return CardsStage(words: lesson.words, onCompleted: onCompleted);
      case VocabStage.listening:
        return ListeningStage(words: lesson.words, onCompleted: onCompleted);
      case VocabStage.mc:
        return MultipleChoiceStage(words: lesson.words, onCompleted: onCompleted);
      case VocabStage.speaking:
        return SpeakingStage(words: lesson.words, onCompleted: onCompleted);
    }
  }
}
