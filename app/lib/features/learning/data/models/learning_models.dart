class LanguageDto {
  LanguageDto({required this.id, required this.code, required this.name, this.description});
  final int id;
  final String code;
  final String name;
  final String? description;

  factory LanguageDto.fromJson(Map<String, dynamic> j) => LanguageDto(
        id: j['id'] as int,
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
      );
}

class TopicDto {
  TopicDto({
    required this.id,
    required this.slug,
    required this.title,
    this.titleRu,
    this.titleKk,
    required this.level,
    required this.order,
    required this.wordCount,
    required this.lessonsCount,
    this.completedLessons = 0,
  });

  final int id;
  final String slug;
  final String title;
  final String? titleRu;
  final String? titleKk;
  final String level;
  final int order;
  final int wordCount;
  final int lessonsCount;
  final int completedLessons;

  factory TopicDto.fromJson(Map<String, dynamic> j) => TopicDto(
        id: j['id'] as int,
        slug: j['slug'] as String,
        title: j['title'] as String,
        titleRu: j['title_ru'] as String?,
        titleKk: j['title_kk'] as String?,
        level: j['level'] as String,
        order: j['order'] as int,
        wordCount: (j['word_count'] as int?) ?? 0,
        lessonsCount: (j['lessons_count'] as int?) ?? 0,
        completedLessons: (j['completed_lessons'] as int?) ?? 0,
      );

  String localizedTitle(String localeCode) {
    return switch (localeCode) {
      'ru' => titleRu ?? title,
      'kk' => titleKk ?? title,
      _ => title,
    };
  }
}

class WordDto {
  WordDto({
    required this.id,
    required this.lemma,
    this.partOfSpeech,
    this.transcriptionIpa,
    this.translationRu,
    this.translationKk,
    this.exampleSentence,
    this.exampleTranslationRu,
    this.exampleTranslationKk,
    this.audioUrl,
    this.imageUrl,
    required this.level,
    required this.sublevel,
    this.frequencyRank,
  });

  final int id;
  final String lemma;
  final String? partOfSpeech;
  final String? transcriptionIpa;
  final String? translationRu;
  final String? translationKk;
  final String? exampleSentence;
  final String? exampleTranslationRu;
  final String? exampleTranslationKk;
  final String? audioUrl;
  final String? imageUrl;
  final String level;
  final int sublevel;
  final int? frequencyRank;

  String get cefrBadge => sublevel == 2 ? '$level.2' : (level.startsWith('B2') ? '$level.1' : level);

  String localizedTranslation(String localeCode) {
    return switch (localeCode) {
      'ru' => translationRu ?? translationKk ?? '',
      'kk' => translationKk ?? translationRu ?? '',
      _ => translationRu ?? translationKk ?? '',
    };
  }

  String? localizedExampleTranslation(String localeCode) {
    return switch (localeCode) {
      'ru' => exampleTranslationRu,
      'kk' => exampleTranslationKk,
      _ => exampleTranslationRu,
    };
  }

  factory WordDto.fromJson(Map<String, dynamic> j) => WordDto(
        id: j['id'] as int,
        lemma: j['lemma'] as String,
        partOfSpeech: j['part_of_speech'] as String?,
        transcriptionIpa: j['transcription_ipa'] as String?,
        translationRu: j['translation_ru'] as String?,
        translationKk: j['translation_kk'] as String?,
        exampleSentence: j['example_sentence'] as String?,
        exampleTranslationRu: j['example_translation_ru'] as String?,
        exampleTranslationKk: j['example_translation_kk'] as String?,
        audioUrl: j['audio_url'] as String?,
        imageUrl: j['image_url'] as String?,
        level: (j['level'] as String?) ?? 'A1',
        sublevel: (j['sublevel'] as int?) ?? 1,
        frequencyRank: j['frequency_rank'] as int?,
      );
}

class LessonSummaryDto {
  LessonSummaryDto({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.xpReward,
    required this.estimatedMinutes,
    required this.isCompleted,
    required this.score,
  });

  final int id;
  final String title;
  final String? description;
  final String type;
  final int xpReward;
  final int estimatedMinutes;
  final bool isCompleted;
  final int score;

  factory LessonSummaryDto.fromJson(Map<String, dynamic> j) => LessonSummaryDto(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        type: j['type'] as String,
        xpReward: (j['xp_reward'] as int?) ?? 10,
        estimatedMinutes: (j['estimated_minutes'] as int?) ?? 5,
        isCompleted: (j['is_completed'] as bool?) ?? false,
        score: (j['score'] as int?) ?? 0,
      );
}

class QuestionDto {
  QuestionDto({
    required this.id,
    required this.type,
    required this.order,
    required this.content,
  });

  final int id;
  final String type; // multiple_choice | text_input | fill_blanks
  final int order;
  final Map<String, dynamic> content;

  factory QuestionDto.fromJson(Map<String, dynamic> j) => QuestionDto(
        id: j['id'] as int,
        type: j['type'] as String,
        order: j['order'] as int,
        content: Map<String, dynamic>.from(j['content'] as Map),
      );
}

class LessonDetailDto extends LessonSummaryDto {
  LessonDetailDto({
    required super.id,
    required super.title,
    super.description,
    required super.type,
    required super.xpReward,
    required super.estimatedMinutes,
    required super.isCompleted,
    required super.score,
    required this.questions,
  });

  final List<QuestionDto> questions;

  factory LessonDetailDto.fromJson(Map<String, dynamic> j) => LessonDetailDto(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        type: j['type'] as String,
        xpReward: (j['xp_reward'] as int?) ?? 10,
        estimatedMinutes: (j['estimated_minutes'] as int?) ?? 5,
        isCompleted: (j['is_completed'] as bool?) ?? false,
        score: (j['score'] as int?) ?? 0,
        questions: ((j['questions'] as List?) ?? const <dynamic>[])
            .map((dynamic e) => QuestionDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class SubmitResultDto {
  SubmitResultDto({
    required this.score,
    required this.total,
    required this.correct,
    required this.mistakes,
    required this.xpEarned,
    required this.isCompleted,
  });

  final int score;
  final int total;
  final int correct;
  final int mistakes;
  final int xpEarned;
  final bool isCompleted;

  factory SubmitResultDto.fromJson(Map<String, dynamic> j) => SubmitResultDto(
        score: j['score'] as int,
        total: j['total'] as int,
        correct: j['correct'] as int,
        mistakes: j['mistakes'] as int,
        xpEarned: (j['xp_earned'] as int?) ?? 0,
        isCompleted: (j['is_completed'] as bool?) ?? false,
      );
}
