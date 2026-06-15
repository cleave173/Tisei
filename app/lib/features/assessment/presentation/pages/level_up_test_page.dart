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

class LevelUpTestPage extends ConsumerStatefulWidget {
  const LevelUpTestPage({super.key});

  @override
  ConsumerState<LevelUpTestPage> createState() => _LevelUpTestPageState();
}

class _LevelUpTestPageState extends ConsumerState<LevelUpTestPage> {
  AssessmentStartDto? _session;
  bool _introShown = false;
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
  }

  Future<void> _start(String translationLang) async {
    setState(() {
      _translationLang = translationLang;
      _introShown = true;
      _loading = true;
      _error = null;
    });
    try {
      final AssessmentStartDto s =
          await ref.read(assessmentRepositoryProvider).startLevelUp(translationLang: translationLang);
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
    if (_pickedOption != null) return;
    setState(() => _pickedOption = option);
    _answers[_q.wordId] = option;
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
      final AssessmentResultDto r =
          await ref.read(assessmentRepositoryProvider).submitLevelUp(
                attemptId: _session!.attemptId,
                answers: _answers.entries
                    .map((e) => (wordId: e.key, chosen: e.value))
                    .toList(),
                translationLang: _translationLang,
              );
      await ref.read(authControllerProvider.notifier).refresh();
      ref.invalidate(levelStatusProvider);
      if (mounted) {
        final CharacterScenario scenario =
            r.passed ? CharacterScenario.testPassed : CharacterScenario.testFailed;
        final String? imgPath =
            ref.read(characterNotifierProvider).imagePathFor(scenario);
        showCharacterOverlay(context, scenario: scenario, imagePath: imgPath);
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
    if (!_introShown) {
      return _LevelUpIntroScreen(
        onStart: _start,
        onSkip: () => context.go(Routes.home),
      );
    }
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('assessment.level_up_title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('assessment.level_up_title'.tr())),
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(Routes.home),
                child: Text('assessment.go_home'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    if (_result != null) {
      return _LevelUpResultScreen(
        result: _result!,
        fromLevel: _session!.fromLevel,
      );
    }

    final String subtitle = _session!.fromLevel != null
        ? 'assessment.level_up_subtitle'
            .tr(args: <String>[_session!.fromLevel!])
        : 'assessment.level_up_title'.tr();

    return AssessmentQuizScreen(
      title: subtitle,
      question: _q,
      index: _index,
      total: _total,
      pickedOption: _pickedOption,
      submitting: _submitting,
      onPick: _pick,
      onAdvance: _advance,
    );
  }
}

// ---------------------------------------------------------------------------

class _LevelUpResultScreen extends ConsumerWidget {
  const _LevelUpResultScreen({
    required this.result,
    required this.fromLevel,
  });

  final AssessmentResultDto result;
  final String? fromLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? newLevel = result.newLevel;
    final bool passed = result.passed;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 32),
              Icon(
                passed
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_neutral_rounded,
                size: 72,
                color: passed ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                passed
                    ? 'assessment.level_up_passed'.tr()
                    : 'assessment.level_up_failed'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (passed && newLevel != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'assessment.level_up_new_level'.tr(args: <String>[newLevel]),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(child: CefrLevelChip(level: newLevel)),
              ],
              if (!passed) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'assessment.level_up_try_again'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'assessment.score_summary'.tr(args: <String>[
                  result.totalCorrect.toString(),
                  result.totalQuestions.toString(),
                ]),
                style: const TextStyle(fontSize: 16, color: Colors.black54),
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

class _LevelUpIntroScreen extends StatefulWidget {
  const _LevelUpIntroScreen({required this.onStart, required this.onSkip});

  final void Function(String translationLang) onStart;
  final VoidCallback onSkip;

  @override
  State<_LevelUpIntroScreen> createState() => _LevelUpIntroScreenState();
}

class _LevelUpIntroScreenState extends State<_LevelUpIntroScreen> {
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
              Icon(Icons.trending_up_rounded, size: 88, color: primary),
              const SizedBox(height: 28),
              // ── Title ─────────────────────────────────────────────────────
              Text(
                'assessment.level_up_intro_title'.tr(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // ── Body ──────────────────────────────────────────────────────
              Text(
                'assessment.level_up_intro_body'.tr(),
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
                  'assessment.level_up_take_test'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              // ── Cancel/Skip ───────────────────────────────────────────────
              OutlinedButton(
                onPressed: widget.onSkip,
                child: Text(
                  'assessment.go_home'.tr(),
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
