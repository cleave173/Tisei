import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../offline/connectivity_service.dart';

/// Bottom-navigation scaffold used by the main app shell.
/// Tabs (in order): Learn, Search, Translation, Achievement, Profile.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Scaffold(
      body: Column(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: online ? 0 : 32,
            color: Colors.orange.shade800,
            child: online
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'common.offline'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (int i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: 'nav.learn'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: 'nav.search'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.translate),
            label: 'nav.translation'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: 'nav.achievement'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'nav.profile'.tr(),
          ),
        ],
      ),
    );
  }
}
