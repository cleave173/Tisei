import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/env.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/models/user_dto.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

// XP needed to finish level N (and advance to N+1)
int _xpForLevel(int level) => level * 200;
// Total XP accumulated at the start of level N
int _xpAtLevelStart(int level) => 100 * level * (level - 1);

Color _cefrColor(String? cefr) => switch (cefr?.toUpperCase()) {
  'A1' => const Color(0xFF1565C0),
  'A2' => const Color(0xFF0097A7),
  'B1' => const Color(0xFF2E7D32),
  'B2' => const Color(0xFF558B2F),
  'C1' => const Color(0xFFE65100),
  'C2' => const Color(0xFFC62828),
  _ => const Color(0xFF757575),
};

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _refresh() async {
    await ref.read(authControllerProvider.notifier).refresh();
  }

  Future<void> _changeAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      await ref.read(authRepositoryProvider).uploadAvatar(file.path);
      await ref.read(authControllerProvider.notifier).refresh();
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _confirmLogout() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('profile.logout'.tr()),
        content: Text('profile.logout_confirm'.tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('profile.logout'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(Routes.starter);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState s = ref.watch(authControllerProvider);

    if (s is AuthInitial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (s is! AuthAuthenticated) {
      return _GuestProfilePage();
    }

    final UserDto user = s.user;
    final ProfileDto? p = user.profile;

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _ProfileHeader(user: user, onChangeAvatar: _changeAvatar),
            if (p != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _XpCard(profile: p),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _StatsRow(profile: p),
              ),
            ],
            const SizedBox(height: 16),
            _MenuSection(onLogout: _confirmLogout),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onChangeAvatar});
  final UserDto user;
  final VoidCallback onChangeAvatar;

  static String _resolveUrl(String url) =>
      url.startsWith('http') ? url : '${Env.backendBaseUrl}$url';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? cefr = user.profile?.cefrLevel;
    final double topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[cs.primary, cs.secondary],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 28),
      child: Column(
        children: <Widget>[
          GestureDetector(
            onTap: onChangeAvatar,
            child: Stack(
              children: <Widget>[
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white24,
                  backgroundImage: user.avatarUrl != null
                      ? CachedNetworkImageProvider(_resolveUrl(user.avatarUrl!))
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          if (cefr != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _cefrColor(cefr),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cefr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── XP progress card ──────────────────────────────────────────────────────────

class _XpCard extends StatelessWidget {
  const _XpCard({required this.profile});
  final ProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final int level = profile.level;
    final int xp = profile.experiencePoints;
    final int start = _xpAtLevelStart(level);
    final int needed = _xpForLevel(level);
    final int inLevel = (xp - start).clamp(0, needed);
    final double fraction = needed > 0 ? inLevel / needed : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'profile.level_n'.tr(args: <String>['$level']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'profile.xp_progress'.tr(
                    args: <String>['$inLevel', '$needed'],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'profile.xp_to_next'.tr(
                args: <String>['${(needed - inLevel).clamp(0, needed)}'],
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final ProfileDto profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFE65100),
          label: 'profile.streak'.tr(),
          value: '${profile.streakDays}',
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Icons.star_rounded,
          color: const Color(0xFFF9A825),
          label: 'profile.xp'.tr(),
          value: '${profile.experiencePoints}',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Guest screen ──────────────────────────────────────────────────────────────

class _GuestProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.person_rounded, size: 20),
            const SizedBox(width: 8),
            Text('profile.title'.tr()),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 48,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 52,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'auth.guest_title'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'auth.guest_hint'.tr(),
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go(Routes.register),
                icon: const Icon(Icons.person_add_outlined),
                label: Text('auth.register'.tr()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.login),
                icon: const Icon(Icons.login_outlined),
                label: Text('auth.login'.tr()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu ──────────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: Text('profile.achievements'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.achievements),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text('settings.title'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.settings),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(
            'profile.logout'.tr(),
            style: const TextStyle(color: Colors.red),
          ),
          onTap: onLogout,
        ),
      ],
    );
  }
}
