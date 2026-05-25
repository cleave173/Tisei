import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../providers/auth_controller.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool _isStrongPassword(String p) =>
    p.length >= 8 &&
    p.contains(RegExp(r'[a-zA-Z]')) &&
    p.contains(RegExp(r'\d'));

/// 4-step registration: age → name → email → password.
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
  final TextEditingController _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  String? _ageErr;
  String? _nameErr;
  String? _emailErr;
  String? _passErr;
  String? _confirmErr;

  @override
  void dispose() {
    _ctrl.dispose();
    _age.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Returns true if current step passes validation.
  bool _validateStep() {
    switch (_step) {
      case 0:
        final int? age = int.tryParse(_age.text.trim());
        if (age == null || age < 4 || age > 120) {
          setState(() => _ageErr = 'auth.age_invalid'.tr());
          return false;
        }
        setState(() => _ageErr = null);
      case 1:
        if (_name.text.trim().length < 2) {
          setState(() => _nameErr = 'auth.name_invalid'.tr());
          return false;
        }
        setState(() => _nameErr = null);
      case 2:
        if (!_emailRegex.hasMatch(_email.text.trim())) {
          setState(() => _emailErr = 'auth.email_invalid'.tr());
          return false;
        }
        setState(() => _emailErr = null);
      case 3:
        if (!_isStrongPassword(_password.text)) {
          setState(() { _passErr = 'auth.password_weak'.tr(); _confirmErr = null; });
          return false;
        }
        if (_password.text != _confirm.text) {
          setState(() { _passErr = null; _confirmErr = 'auth.passwords_mismatch'.tr(); });
          return false;
        }
        setState(() { _passErr = null; _confirmErr = null; });
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validateStep()) return;
    if (_step < 3) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.ease);
      setState(() => _step++);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
            age: int.parse(_age.text.trim()),
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
                  hint: 'auth.age_hint'.tr(),
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) { if (_ageErr != null) setState(() => _ageErr = null); },
                    onSubmitted: (_) => _next(),
                    decoration: InputDecoration(
                      labelText: 'auth.age'.tr(),
                      errorText: _ageErr,
                    ),
                  ),
                ),
                _Step(
                  label: 'auth.name'.tr(),
                  hint: 'auth.name_hint'.tr(),
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) { if (_nameErr != null) setState(() => _nameErr = null); },
                    onSubmitted: (_) => _next(),
                    decoration: InputDecoration(
                      labelText: 'auth.name'.tr(),
                      errorText: _nameErr,
                    ),
                  ),
                ),
                _Step(
                  label: 'auth.email'.tr(),
                  hint: 'auth.email_hint'.tr(),
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) { if (_emailErr != null) setState(() => _emailErr = null); },
                    onSubmitted: (_) => _next(),
                    decoration: InputDecoration(
                      labelText: 'auth.email'.tr(),
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _emailErr,
                    ),
                  ),
                ),
                _Step(
                  label: 'auth.password'.tr(),
                  hint: 'auth.password_requirements'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) { if (_passErr != null) setState(() => _passErr = null); },
                        decoration: InputDecoration(
                          labelText: 'auth.password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          errorText: _passErr,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) { if (_confirmErr != null) setState(() => _confirmErr = null); },
                        onSubmitted: (_) => _next(),
                        decoration: InputDecoration(
                          labelText: 'auth.password_confirm'.tr(),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          errorText: _confirmErr,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: _busy ? null : _next,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_step == 3 ? 'common.finish'.tr() : 'common.next'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.child, this.hint});
  final String label;
  final String? hint;
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
          if (hint != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(hint!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
