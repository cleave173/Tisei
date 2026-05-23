import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palettes.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ThemeState {
  const ThemeState({
    this.paletteIndex = 0,
    this.themeMode = ThemeMode.system,
  });

  final int paletteIndex;
  final ThemeMode themeMode;

  AppPalette get palette => kAppPalettes[paletteIndex];

  ThemeState copyWith({int? paletteIndex, ThemeMode? themeMode}) => ThemeState(
        paletteIndex: paletteIndex ?? this.paletteIndex,
        themeMode: themeMode ?? this.themeMode,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static const String _kPaletteKey = 'theme_palette';
  static const String _kModeKey = 'theme_mode';

  static ThemeState _load(SharedPreferences prefs) {
    final int idx =
        (prefs.getInt(_kPaletteKey) ?? 0).clamp(0, kAppPalettes.length - 1);
    final ThemeMode mode = switch (prefs.getString(_kModeKey) ?? 'system') {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeState(paletteIndex: idx, themeMode: mode);
  }

  Future<void> setPalette(int index) async {
    state = state.copyWith(paletteIndex: index);
    await _prefs.setInt(_kPaletteKey, index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }
}

// ---------------------------------------------------------------------------
// Provider — must be overridden in main() with a real SharedPreferences.
// ---------------------------------------------------------------------------

// ignore: avoid_late_keyword
final StateNotifierProvider<ThemeNotifier, ThemeState> themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>(
  (_) => throw UnimplementedError(
    'themeNotifierProvider must be overridden in ProviderScope',
  ),
);
