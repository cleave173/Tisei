import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class SpeakingResultDto {
  const SpeakingResultDto({
    required this.score,
    required this.accuracyScore,
    required this.isPass,
    required this.passThreshold,
    required this.feedback,
    required this.recognizedNormalized,
  });

  final int score;
  final int accuracyScore;
  final bool isPass;
  final int passThreshold;
  final String feedback; // excellent | good | close | try_again | no_speech_detected
  final String recognizedNormalized;

  factory SpeakingResultDto.fromJson(Map<String, dynamic> j) => SpeakingResultDto(
        score: (j['score'] as int?) ?? 0,
        accuracyScore: (j['accuracy_score'] as int?) ?? 0,
        isPass: (j['is_pass'] as bool?) ?? false,
        passThreshold: (j['pass_threshold'] as int?) ?? 80,
        feedback: (j['feedback'] as String?) ?? 'try_again',
        recognizedNormalized: (j['recognized_normalized'] as String?) ?? '',
      );
}

class SpeakingRepository {
  SpeakingRepository(this._api);
  final ApiClient _api;

  Future<SpeakingResultDto> evaluate({
    required String targetText,
    required String recognizedText,
    String locale = 'en-US',
  }) async {
    final dynamic data = await _api.post(
      '/speaking/evaluate',
      body: <String, dynamic>{
        'target_text': targetText,
        'recognized_text': recognizedText,
        'locale': locale,
      },
    );
    return SpeakingResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final Provider<SpeakingRepository> speakingRepositoryProvider = Provider<SpeakingRepository>(
  (Ref ref) => SpeakingRepository(ref.read(apiClientProvider)),
);
