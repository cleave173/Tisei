import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState s = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: switch (s) {
        AuthAuthenticated(:final user) => ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: user.avatarUrl != null
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 40, color: Colors.white),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(user.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              Text(user.email,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _StatTile(label: 'profile.level'.tr(), value: '${user.profile?.level ?? 1}'),
                  _StatTile(
                      label: 'profile.xp'.tr(),
                      value: '${user.profile?.experiencePoints ?? 0}'),
                  _StatTile(
                      label: 'profile.streak'.tr(),
                      value: '${user.profile?.streakDays ?? 0}'),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text('profile.achievements'.tr()),
                onTap: () => context.go(Routes.achievements),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text('settings.title'.tr()),
                onTap: () => context.push(Routes.settings),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text('profile.logout'.tr(), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go(Routes.starter);
                },
              ),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
