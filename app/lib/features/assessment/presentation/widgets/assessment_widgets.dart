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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'assessment.question_of'.tr(
                    args: <String>[(index + 1).toString(), total.toString()],
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                CefrLevelChip(level: question.level),
              ],
            ),
          ),
          // ── Honest-answer reminder ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'assessment.answer_honestly'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'assessment.translate_word'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.lemma,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (question.ipa != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '/${question.ipa}/',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ...question.options.map(
                    (String opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AssessmentOptionButton(
                        label: opt,
                        picked: pickedOption,
                        onTap: answered ? null : () => onPick(opt),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      child: TextButton(
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
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color borderColor =
        isThis ? primary : Theme.of(context).colorScheme.outline;
    final Color? bgColor =
        isThis ? primary.withValues(alpha: 0.08) : null;

    return Material(
      color: bgColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isThis ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isThis ? FontWeight.w600 : FontWeight.normal,
              color: isThis ? primary : null,
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
  const AssessmentScoreBreakdown({
    super.key,
    required this.scoresByLevel,
  });

  final Map<String, LevelScoreDto> scoresByLevel;

  @override
  Widget build(BuildContext context) {
    const List<String> order = <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final List<String> keys =
        order.where((k) => scoresByLevel.containsKey(k)).toList();
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
                  child:
                      Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 0.7 ? const Color(0xFF4CD964) : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${s.correct}/${s.total}',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
