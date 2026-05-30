import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/models/assessment_dto.dart';

class AssessmentQuizScreen extends StatelessWidget {
  const AssessmentQuizScreen({
    super.key,
    required this.title,
    required this.question,
    required this.index,
    required this.total,
    required this.pickedOption,
    required this.submitting,
    required this.onPick,
    required this.onAdvance,
    this.onSkip,
  });

  final String title;
  final AssessmentQuestionDto question;
  final int index;
  final int total;
  final String? pickedOption;
  final bool submitting;
  final void Function(String) onPick;
  final VoidCallback onAdvance;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final bool answered = pickedOption != null;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.psychology_alt_rounded, size: 20),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'assessment.question_of'.tr(
                      args: <String>[(index + 1).toString(), total.toString()],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Honest-answer reminder ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'assessment.answer_honestly'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onPrimaryContainer,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.7),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'assessment.translate_word'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          question.lemma,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ...question.options.map(
                    (String opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AssessmentOptionButton(
                        label: opt,
                        picked: pickedOption,
                        onTap: () => onPick(opt),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (answered)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting ? null : onAdvance,
                        child: Text(
                          index == total - 1
                              ? 'common.finish'.tr()
                              : 'common.next'.tr(),
                        ),
                      ),
                    )
                  else if (onSkip != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSkip,
                        child: Text(
                          'assessment.dont_know'.tr(),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssessmentOptionButton extends StatelessWidget {
  const AssessmentOptionButton({
    super.key,
    required this.label,
    required this.picked,
    required this.onTap,
  });

  final String label;
  final String? picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isThis = picked == label;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color borderColor = isThis
        ? cs.primary
        : cs.outlineVariant.withValues(alpha: 0.9);
    final Color bgColor = isThis
        ? cs.primaryContainer.withValues(alpha: 0.5)
        : cs.surfaceContainerLowest;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isThis ? 1.8 : 1.2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isThis ? FontWeight.w700 : FontWeight.w600,
              color: isThis ? cs.primary : cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class CefrLevelChip extends StatelessWidget {
  const CefrLevelChip({super.key, required this.level});
  final String level;

  static const Map<String, Color> _colors = <String, Color>{
    'A1': Color(0xFF4CAF50),
    'A2': Color(0xFF8BC34A),
    'B1': Color(0xFF2196F3),
    'B2': Color(0xFF3F51B5),
    'C1': Color(0xFF9C27B0),
    'C2': Color(0xFFE91E63),
  };

  @override
  Widget build(BuildContext context) {
    final Color color = _colors[level] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AssessmentScoreBreakdown extends StatelessWidget {
  const AssessmentScoreBreakdown({super.key, required this.scoresByLevel});

  final Map<String, LevelScoreDto> scoresByLevel;

  @override
  Widget build(BuildContext context) {
    const List<String> order = <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final List<String> keys = order
        .where((k) => scoresByLevel.containsKey(k))
        .toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'assessment.breakdown'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...keys.map((String k) {
          final LevelScoreDto s = scoresByLevel[k]!;
          if (s.total == 0) return const SizedBox.shrink();
          final double pct = s.correct / s.total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 36,
                  child: Text(
                    k,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 0.7 ? const Color(0xFF4CD964) : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${s.correct}/${s.total}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
