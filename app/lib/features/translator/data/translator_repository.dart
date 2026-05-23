import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class TranslationDto {
  TranslationDto({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.sourceText,
    required this.translatedText,
    required this.mode,
    required this.isFavorite,
    required this.createdAt,
  });

  final int id;
  final String sourceLang;
  final String targetLang;
  final String sourceText;
  final String translatedText;
  final String mode;
  final bool isFavorite;
  final DateTime createdAt;

  factory TranslationDto.fromJson(Map<String, dynamic> j) => TranslationDto(
        id: j['id'] as int,
        sourceLang: j['source_lang'] as String,
        targetLang: j['target_lang'] as String,
        sourceText: j['source_text'] as String,
        translatedText: j['translated_text'] as String,
        mode: j['mode'] as String,
        isFavorite: (j['is_favorite'] as bool?) ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class TranslationResultDto {
  TranslationResultDto({
    required this.sourceLang,
    required this.targetLang,
    required this.sourceText,
    required this.translatedText,
    this.historyId,
  });

  final String sourceLang;
  final String targetLang;
  final String sourceText;
  final String translatedText;
  final int? historyId;

  factory TranslationResultDto.fromJson(Map<String, dynamic> j) => TranslationResultDto(
        sourceLang: j['source_lang'] as String,
        targetLang: j['target_lang'] as String,
        sourceText: j['source_text'] as String,
        translatedText: j['translated_text'] as String,
        historyId: j['history_id'] as int?,
      );
}

class TranslatorRepository {
  TranslatorRepository(this._api);
  final ApiClient _api;

  Future<TranslationResultDto> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    String mode = 'text',
    bool saveHistory = true,
  }) async {
    final dynamic data = await _api.post('/translator/text', body: {
      'text': text,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'mode': mode,
      'save_history': saveHistory,
    });
    return TranslationResultDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<TranslationDto>> history({bool favoritesOnly = false, int limit = 50}) async {
    final dynamic data = await _api.get(
      '/translator/history',
      query: {'favorites_only': favoritesOnly, 'limit': limit},
    );
    return (data as List)
        .map((dynamic e) => TranslationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TranslationDto> toggleFavorite(int id) async {
    final dynamic data = await _api.post('/translator/history/$id/favorite');
    return TranslationDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteItem(int id) async => _api.delete('/translator/history/$id');

  Future<void> clearHistory() async => _api.delete('/translator/history');
}

final Provider<TranslatorRepository> translatorRepositoryProvider =
    Provider<TranslatorRepository>((Ref ref) => TranslatorRepository(ref.read(apiClientProvider)));
