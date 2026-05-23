class AssessmentQuestionDto {
  AssessmentQuestionDto({
    required this.level,
    required this.wordId,
    required this.lemma,
    this.ipa,
    required this.options,
  });

  final String level;
  final int wordId;
  final String lemma;
  final String? ipa;
  final List<String> options;

  factory AssessmentQuestionDto.fromJson(Map<String, dynamic> j) =>
      AssessmentQuestionDto(
        level: j['level'] as String,
        wordId: j['word_id'] as int,
        lemma: j['lemma'] as String,
        ipa: j['ipa'] as String?,
        options: ((j['options'] as List?) ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
      );
}

class AssessmentStartDto {
  AssessmentStartDto({
    required this.attemptId,
    required this.kind,
    this.fromLevel,
    required this.questions,
  });

  final int attemptId;
  final String kind;
  final String? fromLevel;
  final List<AssessmentQuestionDto> questions;

  factory AssessmentStartDto.fromJson(Map<String, dynamic> j) =>
      AssessmentStartDto(
        attemptId: j['attempt_id'] as int,
        kind: j['kind'] as String,
        fromLevel: j['from_level'] as String?,
        questions: ((j['questions'] as List?) ?? <dynamic>[])
            .map((dynamic e) =>
                AssessmentQuestionDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class LevelScoreDto {
  LevelScoreDto({required this.correct, required this.total});

  final int correct;
  final int total;

  factory LevelScoreDto.fromJson(Map<String, dynamic> j) => LevelScoreDto(
        correct: (j['correct'] as int?) ?? 0,
        total: (j['total'] as int?) ?? 0,
      );
}

class AssessmentResultDto {
  AssessmentResultDto({
    required this.attemptId,
    required this.kind,
    required this.scoresByLevel,
    required this.totalCorrect,
    required this.totalQuestions,
    required this.passed,
    this.estimatedLevel,
    this.newLevel,
  });

  final int attemptId;
  final String kind;
  final Map<String, LevelScoreDto> scoresByLevel;
  final int totalCorrect;
  final int totalQuestions;
  final bool passed;
  final String? estimatedLevel;
  final String? newLevel;

  factory AssessmentResultDto.fromJson(Map<String, dynamic> j) =>
      AssessmentResultDto(
        attemptId: j['attempt_id'] as int,
        kind: j['kind'] as String,
        scoresByLevel: (j['scores_by_level'] as Map? ?? <String, dynamic>{}).map(
          (dynamic k, dynamic v) => MapEntry(
            k.toString(),
            LevelScoreDto.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
        totalCorrect: (j['total_correct'] as int?) ?? 0,
        totalQuestions: (j['total_questions'] as int?) ?? 0,
        passed: (j['passed'] as bool?) ?? false,
        estimatedLevel: j['estimated_level'] as String?,
        newLevel: j['new_level'] as String?,
      );
}

class LevelStatusDto {
  LevelStatusDto({
    this.cefrLevel,
    required this.placementDone,
    required this.canLevelUp,
    this.nextLevel,
    this.lastLevelUpAttemptAt,
  });

  final String? cefrLevel;
  final bool placementDone;
  final bool canLevelUp;
  final String? nextLevel;
  final DateTime? lastLevelUpAttemptAt;

  factory LevelStatusDto.fromJson(Map<String, dynamic> j) => LevelStatusDto(
        cefrLevel: j['cefr_level'] as String?,
        placementDone: (j['placement_done'] as bool?) ?? false,
        canLevelUp: (j['can_level_up'] as bool?) ?? false,
        nextLevel: j['next_level'] as String?,
        lastLevelUpAttemptAt: j['last_level_up_attempt_at'] == null
            ? null
            : DateTime.tryParse(j['last_level_up_attempt_at'].toString()),
      );
}
