import 'learning_models.dart';

/// Per-stage flags + overall completion.
class VocabProgressDto {
  const VocabProgressDto({
    required this.cardsDone,
    required this.listeningDone,
    required this.mcDone,
    required this.speakingDone,
    required this.isCompleted,
    required this.xpEarned,
  });

  final bool cardsDone;
  final bool listeningDone;
  final bool mcDone;
  final bool speakingDone;
  final bool isCompleted;
  final int xpEarned;

  factory VocabProgressDto.empty() => const VocabProgressDto(
    cardsDone: false,
    listeningDone: false,
    mcDone: false,
    speakingDone: false,
    isCompleted: false,
    xpEarned: 0,
  );

  factory VocabProgressDto.fromJson(Map<String, dynamic> j) => VocabProgressDto(
    cardsDone: (j['cards_done'] as bool?) ?? false,
    listeningDone: (j['listening_done'] as bool?) ?? false,
    mcDone: (j['mc_done'] as bool?) ?? false,
    speakingDone: (j['speaking_done'] as bool?) ?? false,
    isCompleted: (j['is_completed'] as bool?) ?? false,
    xpEarned: (j['xp_earned'] as int?) ?? 0,
  );

  /// Has the user reviewed all cards? Tests are gated behind this.
  bool get testsUnlocked => cardsDone;
}

class VocabLessonDto {
  const VocabLessonDto({
    required this.index,
    required this.title,
    required this.words,
    required this.progress,
  });

  final int index;
  final String title;
  final List<WordDto> words;
  final VocabProgressDto progress;

  factory VocabLessonDto.fromJson(Map<String, dynamic> j) => VocabLessonDto(
    index: j['index'] as int,
    title: j['title'] as String,
    words: (j['words'] as List)
        .map(
          (dynamic e) => WordDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    progress: VocabProgressDto.fromJson(
      Map<String, dynamic>.from(j['progress'] as Map),
    ),
  );
}

class VocabLessonsListDto {
  const VocabLessonsListDto({
    required this.topicId,
    required this.topicTitle,
    this.topicTitleRu,
    this.topicTitleKk,
    required this.topicLevel,
    required this.lessonSize,
    required this.lessons,
  });

  final int topicId;
  final String topicTitle;
  final String? topicTitleRu;
  final String? topicTitleKk;
  final String topicLevel;
  final int lessonSize;
  final List<VocabLessonDto> lessons;

  factory VocabLessonsListDto.fromJson(Map<String, dynamic> j) =>
      VocabLessonsListDto(
        topicId: j['topic_id'] as int,
        topicTitle: j['topic_title'] as String,
        topicTitleRu: j['topic_title_ru'] as String?,
        topicTitleKk: j['topic_title_kk'] as String?,
        topicLevel: j['topic_level'] as String,
        lessonSize: j['lesson_size'] as int,
        lessons: (j['lessons'] as List)
            .map(
              (dynamic e) =>
                  VocabLessonDto.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );

  String localizedTopicTitle(String localeCode) {
    return switch (localeCode) {
      'ru' => topicTitleRu ?? topicTitle,
      'kk' => topicTitleKk ?? topicTitle,
      _ => topicTitle,
    };
  }
}

class VocabStageResultDto {
  const VocabStageResultDto({
    required this.progress,
    required this.xpEarnedNow,
  });
  final VocabProgressDto progress;
  final int xpEarnedNow;

  factory VocabStageResultDto.fromJson(Map<String, dynamic> j) =>
      VocabStageResultDto(
        progress: VocabProgressDto.fromJson(
          Map<String, dynamic>.from(j['progress'] as Map),
        ),
        xpEarnedNow: (j['xp_earned_now'] as int?) ?? 0,
      );
}

/// Names of stages — used in both API calls and UI.
enum VocabStage { cards, listening, mc, speaking }

extension VocabStageX on VocabStage {
  String get apiName => switch (this) {
    VocabStage.cards => 'cards',
    VocabStage.listening => 'listening',
    VocabStage.mc => 'mc',
    VocabStage.speaking => 'speaking',
  };

  bool isDoneIn(VocabProgressDto p) => switch (this) {
    VocabStage.cards => p.cardsDone,
    VocabStage.listening => p.listeningDone,
    VocabStage.mc => p.mcDone,
    VocabStage.speaking => p.speakingDone,
  };
}
