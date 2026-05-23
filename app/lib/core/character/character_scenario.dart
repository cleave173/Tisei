/// Available character-reaction scenarios.
enum CharacterScenario {
  lessonCompleted,
  testPassed,
  testFailed,
}

extension CharacterScenarioX on CharacterScenario {
  /// Translation key used in the Settings page list.
  String get nameKey => switch (this) {
        CharacterScenario.lessonCompleted => 'character.scenario_lesson_completed',
        CharacterScenario.testPassed => 'character.scenario_test_passed',
        CharacterScenario.testFailed => 'character.scenario_test_failed',
      };

  /// Bold headline shown in the speech bubble.
  String get messageKey => switch (this) {
        CharacterScenario.lessonCompleted => 'character.msg_lesson_completed',
        CharacterScenario.testPassed => 'character.msg_test_passed',
        CharacterScenario.testFailed => 'character.msg_test_failed',
      };

  /// Smaller subtitle shown below the headline.
  String get subMessageKey => switch (this) {
        CharacterScenario.lessonCompleted => 'character.sub_lesson_completed',
        CharacterScenario.testPassed => 'character.sub_test_passed',
        CharacterScenario.testFailed => 'character.sub_test_failed',
      };

  /// Fallback emoji shown when no custom image is set.
  String get defaultEmoji => switch (this) {
        CharacterScenario.lessonCompleted => '🎉',
        CharacterScenario.testPassed => '🌟',
        CharacterScenario.testFailed => '💪',
      };

  /// SharedPreferences key for the stored image path.
  String get prefsKey => switch (this) {
        CharacterScenario.lessonCompleted => 'char_lesson_completed',
        CharacterScenario.testPassed => 'char_test_passed',
        CharacterScenario.testFailed => 'char_test_failed',
      };
}
