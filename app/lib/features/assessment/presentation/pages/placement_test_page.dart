import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/character/character_notifier.dart';
import '../../../../core/character/character_overlay.dart';
import '../../../../core/character/character_scenario.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/assessment_repository.dart';
import '../../data/models/assessment_dto.dart';
import '../widgets/assessment_widgets.dart';

class PlacementTestPage extends ConsumerStatefulWidget {
  const PlacementTestPage({super.key});

  @override
  ConsumerState<PlacementTestPage> createState() => _PlacementTestPageState();
}

class _PlacementTestPageState extends ConsumerState<PlacementTestPage> {
  AssessmentStartDto? _session;
  bool _introShown = false; // starts false — show intro first
  bool _loading = false;
  String? _error;
  String? _translationLang;

  int _index = 0;
  final Map<int, String> _answers = <int, String>{};
  String? _pickedOption;
  bool _submitting = false;
  AssessmentResultDto? _result;

  @override
  void initState() {
    super.initState();
    // Do NOT auto-start — user must tap "Take test" on the intro screen.
  }

  Future<void> _start(String translationLang) async {
    setState(() {
      _translationLang = translationLang;
      _introShown = true;
      _loading = true;
      _error = null;
    });
    try {
      final AssessmentStartDto s = await ref
          .read(assessmentRepositoryProvider)
          .startPlacement(translationLang: translationLang);
      setState(() {
        _session = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppSnackBar.friendlyMessage(e);
        _loading = false;
      });
    }
  }

  AssessmentQuestionDto get _q => _session!.questions[_index];
  int get _total => _session!.questions.length;

  void _pick(String option) {
    setState(() {
      if (_pickedOption == option) {
        _pickedOption = null;
        _answers.remove(_q.wordId);
      } else {
        _pickedOption = option;
        _answers[_q.wordId] = option;
      }
    });
  }

  void _skip() {
    // Submit an empty choice so skipped questions are counted as wrong.
    _answers[_q.wordId] = '';
    _advance();
  }

  void _advance() {
    if (_index < _total - 1) {
      setState(() {
        _index++;
        _pickedOption = null;
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final AssessmentResultDto r = await ref
          .read(assessmentRepositoryProvider)
          .submitPlacement(
            attemptId: _session!.attemptId,
            answers: _answers.entries
                .map(
                  (MapEntry<int, String> e) => (wordId: e.key, chosen: e.value),
                )
                .toList(),
            translationLang: _translationLang,
          );
      await ref.read(authControllerProvider.notifier).refresh();
      ref.invalidate(levelStatusProvider);
      if (mounted) {
        final String? imgPath = ref
            .read(characterNotifierProvider)
            .imagePathFor(CharacterScenario.testPassed);
        showCharacterOverlay(
          context,
          scenario: CharacterScenario.testPassed,
          imagePath: imgPath,
        );
      }
      setState(() => _result = r);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. Intro ─────────────────────────────────────────────────────────────
    if (!_introShown) {
      return _PlacementIntroScreen(
        onStart: _start,
        onSkip: () => context.go(Routes.home),
      );
    }
    // ── 2. Loading ────────────────────────────────────────────────────────────
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('assessment.placement_short_title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // ── 3. Error ──────────────────────────────────────────────────────────────
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('assessment.placement_short_title'.tr())),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _start(_translationLang ?? 'ru'),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    // ── 4. Result ─────────────────────────────────────────────────────────────
    if (_result != null) {
      return _PlacementResultScreen(result: _result!);
    }
    // ── 5. Quiz ───────────────────────────────────────────────────────────────
    return AssessmentQuizScreen(
      title: 'assessment.placement_short_title'.tr(),
      question: _q,
      index: _index,
      total: _total,
      pickedOption: _pickedOption,
      submitting: _submitting,
      onPick: _pick,
      onAdvance: _advance,
      onSkip: _skip,
    );
  }
}

// ---------------------------------------------------------------------------
// Intro screen
// ---------------------------------------------------------------------------

class _PlacementIntroScreen extends StatefulWidget {
  const _PlacementIntroScreen({required this.onStart, required this.onSkip});

  final void Function(String translationLang) onStart;
  final VoidCallback onSkip;

  @override
  State<_PlacementIntroScreen> createState() => _PlacementIntroScreenState();
}

class _PlacementIntroScreenState extends State<_PlacementIntroScreen> {
  late String _translationLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _translationLang = context.locale.languageCode == 'kk' ? 'kk' : 'ru';
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),
              // ── Icon ──────────────────────────────────────────────────────
              Icon(Icons.school_rounded, size: 88, color: primary),
              const SizedBox(height: 28),
              // ── Title ─────────────────────────────────────────────────────
              Text(
                'assessment.placement_intro_title'.tr(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // ── Body ──────────────────────────────────────────────────────
              Text(
                'assessment.placement_intro_body'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // ── Translation Language Selector ─────────────────────────────
              Text(
                'games.translation_language'.tr(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _AssessmentLanguageTile(
                      label: 'Русский',
                      selected: _translationLang == 'ru',
                      onTap: () => setState(() => _translationLang = 'ru'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AssessmentLanguageTile(
                      label: 'Қазақша',
                      selected: _translationLang == 'kk',
                      onTap: () => setState(() => _translationLang = 'kk'),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),
              // ── Take test ─────────────────────────────────────────────────
              FilledButton(
                onPressed: () => widget.onStart(_translationLang),
                child: Text(
                  'assessment.take_test'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              // ── Skip ──────────────────────────────────────────────────────
              OutlinedButton(
                onPressed: widget.onSkip,
                child: Text(
                  'assessment.skip_to_beginner'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentLanguageTile extends StatelessWidget {
  const _AssessmentLanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlacementResultScreen extends ConsumerWidget {
  const _PlacementResultScreen({required this.result});

  final AssessmentResultDto result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? level = result.newLevel ?? result.estimatedLevel;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 32),
              const Icon(
                Icons.emoji_events_rounded,
                size: 72,
                color: Colors.amber,
              ),
              const SizedBox(height: 24),
              Text(
                'assessment.placement_done'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (level != null) ...<Widget>[
                const SizedBox(height: 12),
                Center(child: CefrLevelChip(level: level)),
              ],
              const SizedBox(height: 16),
              Text(
                'assessment.score_summary'.tr(
                  args: <String>[
                    result.totalCorrect.toString(),
                    result.totalQuestions.toString(),
                  ],
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AssessmentScoreBreakdown(scoresByLevel: result.scoresByLevel),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: Text('assessment.go_home'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
