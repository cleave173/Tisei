import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'models/learning_models.dart';

class LearningRepository {
  LearningRepository(this._api);
  final ApiClient _api;

  Future<List<LanguageDto>> languages() async {
    final dynamic data = await _api.get('/languages');
    return (data as List)
        .map((dynamic e) => LanguageDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TopicDto>> topics(String languageCode) async {
    final dynamic data = await _api.get('/languages/$languageCode/topics');
    return (data as List)
        .map((dynamic e) => TopicDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<WordDto>> wordsByTopic(int topicId, {String? level, int? sublevel}) async {
    final Map<String, dynamic> qp = <String, dynamic>{};
    if (level != null && level.isNotEmpty) qp['level'] = level;
    if (sublevel != null) qp['sublevel'] = sublevel;
    final dynamic data = await _api.get('/words/by-topic/$topicId', query: qp);
    return (data as List)
        .map((dynamic e) => WordDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<WordDto>> searchWords({
    String language = 'en',
    String? level,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final Map<String, dynamic> qp = <String, dynamic>{
      'language': language,
      'limit': limit,
      'offset': offset,
    };
    if (level != null && level.isNotEmpty) qp['level'] = level;
    if (query != null && query.trim().isNotEmpty) qp['q'] = query.trim();
    final dynamic data = await _api.get('/words/search', query: qp);
    return (data as List)
        .map((dynamic e) => WordDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<LessonSummaryDto>> lessonsByTopic(int topicId) async {
    final dynamic data = await _api.get('/lessons/by-topic/$topicId');
    return (data as List)
        .map((dynamic e) => LessonSummaryDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<LessonDetailDto> lesson(int lessonId) async {
    final dynamic data = await _api.get('/lessons/$lessonId');
    return LessonDetailDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SubmitResultDto> submitLesson({
    required int lessonId,
    required List<({int questionId, dynamic answer})> answers,
    required int timeSpentSeconds,
  }) async {
    final dynamic data = await _api.post(
      '/lessons/$lessonId/submit',
      body: {
        'time_spent_seconds': timeSpentSeconds,
        'answers': answers
            .map((a) => {'question_id': a.questionId, 'answer': a.answer})
            .toList(),
      },
    );
    return SubmitResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>((Ref ref) => LearningRepository(ref.read(apiClientProvider)));

final FutureProviderFamily<List<TopicDto>, String> topicsProvider =
    FutureProvider.family<List<TopicDto>, String>(
  (Ref ref, String code) => ref.read(learningRepositoryProvider).topics(code),
);

final FutureProviderFamily<List<LessonSummaryDto>, int> lessonsByTopicProvider =
    FutureProvider.family<List<LessonSummaryDto>, int>(
  (Ref ref, int topicId) => ref.read(learningRepositoryProvider).lessonsByTopic(topicId),
);

final FutureProviderFamily<LessonDetailDto, int> lessonProvider =
    FutureProvider.family<LessonDetailDto, int>(
  (Ref ref, int id) => ref.read(learningRepositoryProvider).lesson(id),
);

class WordsQuery {
  const WordsQuery({required this.topicId, this.level, this.sublevel});
  final int topicId;
  final String? level;
  final int? sublevel;

  @override
  bool operator ==(Object other) =>
      other is WordsQuery &&
      other.topicId == topicId &&
      other.level == level &&
      other.sublevel == sublevel;

  @override
  int get hashCode => Object.hash(topicId, level, sublevel);
}

final FutureProviderFamily<List<WordDto>, WordsQuery> wordsByTopicProvider =
    FutureProvider.family<List<WordDto>, WordsQuery>(
  (Ref ref, WordsQuery q) => ref
      .read(learningRepositoryProvider)
      .wordsByTopic(q.topicId, level: q.level, sublevel: q.sublevel),
);

class WordsSearchQuery {
  const WordsSearchQuery({this.language = 'en', this.level, this.query});
  final String language;
  final String? level;
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is WordsSearchQuery &&
      other.language == language &&
      other.level == level &&
      other.query == query;

  @override
  int get hashCode => Object.hash(language, level, query);
}

final FutureProviderFamily<List<WordDto>, WordsSearchQuery> wordsSearchProvider =
    FutureProvider.family<List<WordDto>, WordsSearchQuery>(
  (Ref ref, WordsSearchQuery q) => ref
      .read(learningRepositoryProvider)
      .searchWords(language: q.language, level: q.level, query: q.query),
);
