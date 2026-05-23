import 'package:flutter/material.dart';

import '../network/api_exception.dart';

/// Centralized, styled snack-bar helpers.
///
/// All methods are no-ops when [context] is no longer mounted.
class AppSnackBar {
  AppSnackBar._();

  // ── Public API ────────────────────────────────────────────────────────────

  static void showError(BuildContext context, dynamic error) =>
      _show(context, message: _friendly(error), type: _Type.error);

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message: message, type: _Type.success);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message: message, type: _Type.info);

  static void showWarning(BuildContext context, String message) =>
      _show(context, message: message, type: _Type.warning);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts a clean, user-facing message from any thrown value.
  static String friendlyMessage(dynamic e) => _friendly(e);

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

  static void _show(
    BuildContext context, {
    required String message,
    required _Type type,
  }) {
    if (!context.mounted) return;

    final (Color bg, IconData icon, Duration dur) = switch (type) {
      _Type.error => (
          const Color(0xFFC62828),
          Icons.error_outline_rounded,
          const Duration(seconds: 5),
        ),
      _Type.success => (
          const Color(0xFF2E7D32),
          Icons.check_circle_outline_rounded,
          const Duration(seconds: 3),
        ),
      _Type.info => (
          const Color(0xFF1565C0),
          Icons.info_outline_rounded,
          const Duration(seconds: 3),
        ),
      _Type.warning => (
          const Color(0xFFE65100),
          Icons.warning_amber_rounded,
          const Duration(seconds: 4),
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
  }
}

enum _Type { error, success, info, warning }
