import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Maps BCP-47 language codes used by the app to ML Kit [TranslateLanguage].
TranslateLanguage? _toMlKit(String code) {
  return switch (code.toLowerCase().split('-').first) {
    'en' => TranslateLanguage.english,
    'ru' => TranslateLanguage.russian,
    'de' => TranslateLanguage.german,
    'fr' => TranslateLanguage.french,
    'es' => TranslateLanguage.spanish,
    'it' => TranslateLanguage.italian,
    'tr' => TranslateLanguage.turkish,
    'zh' => TranslateLanguage.chinese,
    'ja' => TranslateLanguage.japanese,
    'ko' => TranslateLanguage.korean,
    'ar' => TranslateLanguage.arabic,
    'pt' => TranslateLanguage.portuguese,
    'pl' => TranslateLanguage.polish,
    'nl' => TranslateLanguage.dutch,
    'uk' => TranslateLanguage.ukrainian,
    'hi' => TranslateLanguage.hindi,
    'id' => TranslateLanguage.indonesian,
    'sv' => TranslateLanguage.swedish,
    'cs' => TranslateLanguage.czech,
    _ => null,
  };
}

class MlKitTranslatorService {
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  /// Returns true if the model for [langCode] is already on device.
  Future<bool> isDownloaded(String langCode) async {
    final TranslateLanguage? lang = _toMlKit(langCode);
    if (lang == null) return false;
    return _modelManager.isModelDownloaded(lang.bcpCode);
  }

  /// Downloads the model for [langCode]. Throws on failure.
  Future<void> downloadModel(String langCode) async {
    final TranslateLanguage? lang = _toMlKit(langCode);
    if (lang == null) throw UnsupportedError('Language $langCode not supported offline');
    await _modelManager.downloadModel(lang.bcpCode, isWifiRequired: false);
  }

  /// Deletes the on-device model for [langCode].
  Future<void> deleteModel(String langCode) async {
    final TranslateLanguage? lang = _toMlKit(langCode);
    if (lang == null) return;
    await _modelManager.deleteModel(lang.bcpCode);
  }

  /// Translates [text] on-device. Returns null if the language pair is unsupported.
  Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final TranslateLanguage? src = _toMlKit(sourceLang);
    final TranslateLanguage? tgt = _toMlKit(targetLang);
    if (src == null || tgt == null) return null;

    final OnDeviceTranslator translator = OnDeviceTranslator(
      sourceLanguage: src,
      targetLanguage: tgt,
    );
    try {
      return await translator.translateText(text);
    } finally {
      translator.close();
    }
  }

  /// List all languages that have a model downloaded.
  Future<List<String>> downloadedLanguages() async {
    final List<String> result = <String>[];
    for (final TranslateLanguage lang in TranslateLanguage.values) {
      if (await _modelManager.isModelDownloaded(lang.bcpCode)) {
        result.add(lang.bcpCode);
      }
    }
    return result;
  }
}

final Provider<MlKitTranslatorService> mlKitTranslatorServiceProvider =
    Provider<MlKitTranslatorService>((Ref _) => MlKitTranslatorService());
