import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../providers/auth_controller.dart';

/// 4-step registration: age -> name -> email -> password.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final PageController _ctrl = PageController();
  int _step = 0;

  final TextEditingController _age = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    _age.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _busy = false;

  Future<void> _next() async {
    if (_step < 3) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
      setState(() => _step++);
      return;
    }
    if (_busy) return;
    final int? age = int.tryParse(_age.text.trim());
    if (age == null || _name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 6) {
      AppSnackBar.showWarning(context, 'auth.fill_all_fields'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
            age: age,
          );
      if (mounted) context.go(Routes.placementTest);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('auth.register'.tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.go(Routes.home),
            child: Text('common.skip'.tr()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          LinearProgressIndicator(value: (_step + 1) / 4),
          Expanded(
            child: PageView(
              controller: _ctrl,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _Step(
                  label: 'auth.age'.tr(),
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                _Step(
                  label: 'auth.name'.tr(),
                  child: TextField(controller: _name),
                ),
                _Step(
                  label: 'auth.email'.tr(),
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                _Step(
                  label: 'auth.password'.tr(),
                  child: TextField(
                    controller: _password,
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: _next,
              child: Text(_step == 3 ? 'common.finish'.tr() : 'common.next'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
