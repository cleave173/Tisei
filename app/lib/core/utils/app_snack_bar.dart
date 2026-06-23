import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../network/api_exception.dart';

/// Centralized, styled snack-bar helpers.
///
/// All methods are no-ops when [context] is no longer mounted.
class AppSnackBar {
  AppSnackBar._();

  static final GlobalKey<ScaffoldMessengerState> rootKey =
      GlobalKey<ScaffoldMessengerState>();

  // ── Public API ────────────────────────────────────────────────────────────

  static void showError(
    BuildContext context,
    dynamic error, {
    Duration? duration,
  }) {
    final String raw = _friendly(error);
    _show(message: _localize(raw), type: _Type.error, duration: duration);
  }

  // Maps known backend English messages → localization keys
  static const Map<String, String> _backendKeys = <String, String>{
    'invalid credentials': 'errors.invalid_credentials',
    'user already exists': 'errors.user_exists',
    'inactive user': 'errors.inactive_user',
    'invalid refresh token': 'errors.session_expired',
    'invalid or expired code': 'errors.invalid_code',
    'no internet': 'errors.no_internet',
    'rate limit': 'errors.rate_limited',
    'server error': 'errors.server_error',
    'email already': 'errors.user_exists',
  };

  static String _localize(String raw) {
    final String lower = raw.toLowerCase();
    for (final MapEntry<String, String> e in _backendKeys.entries) {
      if (lower.contains(e.key)) return e.value.tr();
    }
    return raw;
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => _show(message: message, type: _Type.success, duration: duration);

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => _show(message: message, type: _Type.info, duration: duration);

  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => _show(message: message, type: _Type.warning, duration: duration);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts a clean, user-facing message from any thrown value.
  static String friendlyMessage(dynamic e) => _localize(_friendly(e));

  // ── Private ───────────────────────────────────────────────────────────────

  static String _friendly(dynamic e) {
    if (e is ApiException) return e.userMessage;
    if (e is Exception) {
      final String s = e.toString();
      for (final String prefix in <String>[
        'Exception: ',
        'FormatException: ',
        'StateError: ',
      ]) {
        if (s.startsWith(prefix)) return s.substring(prefix.length);
      }
      return s;
    }
    return e?.toString() ?? 'Unknown error';
  }

  static void _show({
    required String message,
    required _Type type,
    Duration? duration,
  }) {
    final (Color bg, IconData icon, Duration defaultDur) = switch (type) {
      _Type.error => (
        const Color(0xFFC62828),
        Icons.error_outline_rounded,
        const Duration(seconds: 5),
      ),
      _Type.success => (
        const Color(0xFF2E7D32),
        Icons.check_circle_outline_rounded,
        const Duration(seconds: 5),
      ),
      _Type.info => (
        const Color(0xFF1565C0),
        Icons.info_outline_rounded,
        const Duration(seconds: 5),
      ),
      _Type.warning => (
        const Color(0xFFE65100),
        Icons.warning_amber_rounded,
        const Duration(seconds: 5),
      ),
    };

    Duration dur = duration ?? defaultDur;

    // Auto-detect experience snackbars and cap duration at 3 seconds
    final String lower = message.toLowerCase();
    if (lower.contains('xp') ||
        lower.contains('хр') || // Cyrillic
        lower.contains('опыт') ||
        lower.contains('experience') ||
        lower.contains('+')) {
      dur = const Duration(seconds: 3);
    }

    final ScaffoldMessengerState? messenger = rootKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: bg,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: dur,
            content: Row(
              children: <Widget>[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: '✕',
              textColor: Colors.white70,
              onPressed: () => rootKey.currentState?.hideCurrentSnackBar(),
            ),
          ),
        );

    // Force close after duration to bypass any system/accessibility overrides
    Future<void>.delayed(dur, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }
}

enum _Type { error, success, info, warning }
