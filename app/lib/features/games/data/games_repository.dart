import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'models/game_dtos.dart';

class GamesRepository {
  GamesRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _body({
    String? topic,
    String language = 'en',
    int count = 8,
    String? level,
  }) {
    final Map<String, dynamic> b = <String, dynamic>{
      'language': language,
      'count': count,
    };
    if (topic != null && topic.trim().isNotEmpty) b['topic'] = topic.trim();
    if (level != null) b['level'] = level;
    return b;
  }

  Future<WordMatchDto> generateWordMatch({
    String? topic,
    String language = 'en',
    int count = 8,
    String? level,
  }) async {
    final dynamic data = await _api.post(
      '/games/word-match/generate',
      body: _body(topic: topic, language: language, count: count, level: level),
    );
    return WordMatchDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WordScrambleDto> generateWordScramble({
    String? topic,
    String language = 'en',
    int count = 8,
    String? level,
  }) async {
    final dynamic data = await _api.post(
      '/games/word-scramble/generate',
      body: _body(topic: topic, language: language, count: count, level: level),
    );
    return WordScrambleDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SentenceBuilderDto> generateSentenceBuilder({
    String? topic,
    String language = 'en',
    int count = 5,
    String? level,
  }) async {
    final dynamic data = await _api.post(
      '/games/sentence-builder/generate',
      body: _body(topic: topic, language: language, count: count, level: level),
    );
    return SentenceBuilderDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<HangmanDto> generateHangman({
    String? topic,
    String language = 'en',
    String? level,
  }) async {
    final dynamic data = await _api.post(
      '/games/hangman/generate',
      body: _body(topic: topic, language: language, level: level),
    );
    return HangmanDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final Provider<GamesRepository> gamesRepositoryProvider = Provider<GamesRepository>(
  (Ref ref) => GamesRepository(ref.read(apiClientProvider)),
);
