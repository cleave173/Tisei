import 'dart:io' show Platform;

/// Compile-time / runtime environment configuration.
/// Override with `--dart-define=API_BASE_URL=https://...` when building.
class Env {
  const Env._();

  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Android emulator needs 10.0.2.2 to reach host machine. iOS sim / macOS use localhost.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final String host = _isAndroid() ? '10.0.2.2' : 'localhost';
    return 'http://$host:8001/api/v1';
  }

  static bool _isAndroid() {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false; // web
    }
  }

  static const String libreTranslateUrl = String.fromEnvironment(
    'LIBRETRANSLATE_URL',
    defaultValue: 'http://localhost:5001',
  );

  static const String googleClientIdAndroid = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_ANDROID',
  );

  static const String googleClientIdIos = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_IOS',
  );
}
