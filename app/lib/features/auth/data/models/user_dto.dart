class UserDto {
  UserDto({
    required this.id,
    required this.email,
    required this.fullName,
    this.age,
    this.avatarUrl,
    this.isVerified = false,
    this.profile,
  });

  final int id;
  final String email;
  final String fullName;
  final int? age;
  final String? avatarUrl;
  final bool isVerified;
  final ProfileDto? profile;

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
        id: j['id'] as int,
        email: j['email'] as String,
        fullName: j['full_name'] as String,
        age: j['age'] as int?,
        avatarUrl: j['avatar_url'] as String?,
        isVerified: (j['is_verified'] as bool?) ?? false,
        profile: j['profile'] is Map<String, dynamic>
            ? ProfileDto.fromJson(j['profile'] as Map<String, dynamic>)
            : null,
      );
}

class ProfileDto {
  ProfileDto({
    this.currentLanguageId,
    required this.experiencePoints,
    required this.level,
    required this.streakDays,
    required this.dailyGoalXp,
    required this.interfaceLanguage,
    required this.darkMode,
    required this.textSize,
    required this.notificationsEnabled,
    this.cefrLevel,
  });

  final int? currentLanguageId;
  final int experiencePoints;
  final int level;
  final int streakDays;
  final int dailyGoalXp;
  final String interfaceLanguage;
  final bool darkMode;
  final String textSize;
  final bool notificationsEnabled;
  final String? cefrLevel;

  factory ProfileDto.fromJson(Map<String, dynamic> j) => ProfileDto(
        currentLanguageId: j['current_language_id'] as int?,
        experiencePoints: (j['experience_points'] as int?) ?? 0,
        level: (j['level'] as int?) ?? 1,
        streakDays: (j['streak_days'] as int?) ?? 0,
        dailyGoalXp: (j['daily_goal_xp'] as int?) ?? 50,
        interfaceLanguage: (j['interface_language'] as String?) ?? 'en',
        darkMode: (j['dark_mode'] as bool?) ?? false,
        textSize: (j['text_size'] as String?) ?? 'medium',
        notificationsEnabled: (j['notifications_enabled'] as bool?) ?? true,
        cefrLevel: j['cefr_level'] as String?,
      );
}

class TokenPair {
  TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> j) => TokenPair(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
      );
}
