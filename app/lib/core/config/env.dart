/// Compile-time / runtime environment configuration.
/// Override with `--dart-define=API_BASE_URL=https://...` when building.
class Env {
  const Env._();

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Android emulator needs 10.0.2.2 to reach host machine. iOS sim / macOS use localhost.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return 'https://tisei-production.up.railway.app/api/v1';
  }

  /// Backend root URL (no /api/v1) — used to resolve relative asset URLs like /uploads/...
  static String get backendBaseUrl =>
      apiBaseUrl.replaceAll(RegExp(r'/api/v1.*$'), '');

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
