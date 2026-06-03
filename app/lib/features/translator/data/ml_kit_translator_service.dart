import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder for an optional on-device translator.
///
/// The Google ML Kit translation plugin currently breaks Apple Silicon iOS 26+
/// simulators because its iOS pods do not provide the required arm64 simulator
/// slices. Keep this API plugin-free so the app can run on iOS simulators; the
/// production translator continues to use the backend fallback.
class MlKitTranslatorService {
  Future<bool> isDownloaded(String langCode) async => false;

  Future<void> downloadModel(String langCode) async {
    throw UnsupportedError('Offline translator models are not bundled');
  }

  Future<void> deleteModel(String langCode) async {}

  Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async => null;

  Future<List<String>> downloadedLanguages() async => <String>[];
}

final Provider<MlKitTranslatorService> mlKitTranslatorServiceProvider =
    Provider<MlKitTranslatorService>((Ref _) => MlKitTranslatorService());
