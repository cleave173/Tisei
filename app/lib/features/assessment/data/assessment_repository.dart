import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'models/assessment_dto.dart';

class AssessmentRepository {
  AssessmentRepository(this._api);
  final ApiClient _api;

  Future<AssessmentStartDto> startPlacement({
    String language = 'en',
    String? translationLang,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{'language': language};
    if (translationLang != null) {
      query['translation_lang'] = translationLang;
    }
    final dynamic data = await _api.post(
      '/assessments/placement/start',
      query: query,
    );
    return AssessmentStartDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AssessmentResultDto> submitPlacement({
    required int attemptId,
    required List<({int wordId, String chosen})> answers,
    String? translationLang,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'attempt_id': attemptId,
      'answers': answers
          .map(
            (a) => <String, dynamic>{'word_id': a.wordId, 'chosen': a.chosen},
          )
          .toList(),
    };
    if (translationLang != null) {
      body['translation_lang'] = translationLang;
    }
    final dynamic data = await _api.post(
      '/assessments/placement/submit',
      body: body,
    );
    return AssessmentResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AssessmentStartDto> startLevelUp({
    String language = 'en',
    String? translationLang,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{'language': language};
    if (translationLang != null) {
      query['translation_lang'] = translationLang;
    }
    final dynamic data = await _api.post(
      '/assessments/level-up/start',
      query: query,
    );
    return AssessmentStartDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AssessmentResultDto> submitLevelUp({
    required int attemptId,
    required List<({int wordId, String chosen})> answers,
    String? translationLang,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'attempt_id': attemptId,
      'answers': answers
          .map(
            (a) => <String, dynamic>{'word_id': a.wordId, 'chosen': a.chosen},
          )
          .toList(),
    };
    if (translationLang != null) {
      body['translation_lang'] = translationLang;
    }
    final dynamic data = await _api.post(
      '/assessments/level-up/submit',
      body: body,
    );
    return AssessmentResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<LevelStatusDto> getStatus({String language = 'en'}) async {
    final dynamic data = await _api.get(
      '/assessments/me/status',
      query: <String, dynamic>{'language': language},
    );
    return LevelStatusDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final Provider<AssessmentRepository> assessmentRepositoryProvider =
    Provider<AssessmentRepository>(
      (Ref ref) => AssessmentRepository(ref.read(apiClientProvider)),
    );

final FutureProvider<LevelStatusDto> levelStatusProvider =
    FutureProvider<LevelStatusDto>((Ref ref) {
      ref.watch(authControllerProvider);
      return ref.read(assessmentRepositoryProvider).getStatus();
    });
