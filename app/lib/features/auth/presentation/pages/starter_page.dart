import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

class StarterPage extends StatelessWidget {
  const StarterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Icon(Icons.translate, size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'app.name'.tr(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'app.tagline'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.push(Routes.register),
                child: Text('auth.register'.tr()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push(Routes.login),
                child: Text('auth.login'.tr()),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
