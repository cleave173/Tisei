import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../providers/auth_controller.dart';

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final String email = _email.text.trim();
    final String pass = _password.text;
    String? emailErr;
    String? passErr;
    if (email.isEmpty) {
      emailErr = 'auth.fields_required'.tr();
    } else if (!_emailRe.hasMatch(email)) {
      emailErr = 'auth.email_invalid'.tr();
    }
    if (pass.isEmpty) passErr = 'auth.fields_required'.tr();
    setState(() { _emailError = emailErr; _passError = passErr; });
    return emailErr == null && passErr == null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            _email.text.trim(),
            _password.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        context.go(Routes.home);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final GoogleSignIn google = GoogleSignIn(scopes: const <String>['email']);
      final GoogleSignInAccount? acc = await google.signIn();
      if (acc == null) return;
      final GoogleSignInAuthentication tokens = await acc.authentication;
      final String? idToken = tokens.idToken;
      if (idToken == null) throw Exception('No id_token from Google');
      await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.login'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_busy,
              onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
              decoration: InputDecoration(
                labelText: 'auth.email'.tr(),
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
              ),
              onSubmitted: (_) => _passFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              focusNode: _passFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              enabled: !_busy,
              onChanged: (_) { if (_passError != null) setState(() => _passError = null); },
              decoration: InputDecoration(
                labelText: 'auth.password'.tr(),
                prefixIcon: const Icon(Icons.lock_outlined),
                errorText: _passError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => context.push(Routes.forgotPassword),
                child: Text('auth.forgot_password'.tr()),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('auth.login'.tr()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _google,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: Text('auth.login_with_google'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
