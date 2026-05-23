import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'character_scenario.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CharacterState {
  const CharacterState({this.imagePaths = const <CharacterScenario, String>{}});

  final Map<CharacterScenario, String> imagePaths;

  String? imagePathFor(CharacterScenario s) => imagePaths[s];

  CharacterState _withScenario(CharacterScenario s, String? path) {
    final Map<CharacterScenario, String> updated =
        Map<CharacterScenario, String>.from(imagePaths);
    if (path == null) {
      updated.remove(s);
    } else {
      updated[s] = path;
    }
    return CharacterState(imagePaths: updated);
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CharacterNotifier extends StateNotifier<CharacterState> {
  CharacterNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static CharacterState _load(SharedPreferences prefs) {
    final Map<CharacterScenario, String> paths = <CharacterScenario, String>{};
    for (final CharacterScenario s in CharacterScenario.values) {
      final String? p = prefs.getString(s.prefsKey);
      if (p != null) paths[s] = p;
    }
    return CharacterState(imagePaths: paths);
  }

  Future<void> setImage(CharacterScenario scenario, String path) async {
    state = state._withScenario(scenario, path);
    await _prefs.setString(scenario.prefsKey, path);
  }

  Future<void> removeImage(CharacterScenario scenario) async {
    state = state._withScenario(scenario, null);
    await _prefs.remove(scenario.prefsKey);
  }
}

// ---------------------------------------------------------------------------
// Provider — overridden in main() with a real SharedPreferences instance.
// ---------------------------------------------------------------------------

final StateNotifierProvider<CharacterNotifier, CharacterState>
    characterNotifierProvider =
    StateNotifierProvider<CharacterNotifier, CharacterState>(
  (_) => throw UnimplementedError(
    'characterNotifierProvider must be overridden in ProviderScope',
  ),
);
