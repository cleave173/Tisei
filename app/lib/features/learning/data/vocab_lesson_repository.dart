import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'models/vocab_lesson_models.dart';

class VocabLessonRepository {
  VocabLessonRepository(this._api);
  final ApiClient _api;

  Future<VocabLessonsListDto> listByTopic(int topicId) async {
    final dynamic data = await _api.get('/vocab-lessons/topic/$topicId');
    return VocabLessonsListDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<VocabLessonDto> getLesson(int topicId, int lessonIndex) async {
    final dynamic data = await _api.get('/vocab-lessons/topic/$topicId/$lessonIndex');
    return VocabLessonDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<VocabStageResultDto> markStage({
    required int topicId,
    required int lessonIndex,
    required VocabStage stage,
  }) async {
    final dynamic data = await _api.post(
      '/vocab-lessons/topic/$topicId/$lessonIndex/stage',
      body: <String, dynamic>{'stage': stage.apiName},
    );
    return VocabStageResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final Provider<VocabLessonRepository> vocabLessonRepositoryProvider =
    Provider<VocabLessonRepository>(
  (Ref ref) => VocabLessonRepository(ref.read(apiClientProvider)),
);

/// List of vocab lessons for a topic.
final FutureProviderFamily<VocabLessonsListDto, int> vocabLessonsByTopicProvider =
    FutureProvider.family<VocabLessonsListDto, int>(
  (Ref ref, int topicId) {
    ref.watch(authControllerProvider);
    return ref.read(vocabLessonRepositoryProvider).listByTopic(topicId);
  },
);

/// One vocab lesson (used by the lesson page).
class VocabLessonKey {
  const VocabLessonKey({required this.topicId, required this.lessonIndex});
  final int topicId;
  final int lessonIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabLessonKey &&
          topicId == other.topicId &&
          lessonIndex == other.lessonIndex);

  @override
  int get hashCode => Object.hash(topicId, lessonIndex);
}

final FutureProviderFamily<VocabLessonDto, VocabLessonKey> vocabLessonProvider =
    FutureProvider.family<VocabLessonDto, VocabLessonKey>(
  (Ref ref, VocabLessonKey key) {
    ref.watch(authControllerProvider);
    return ref.read(vocabLessonRepositoryProvider).getLesson(key.topicId, key.lessonIndex);
  },
);
