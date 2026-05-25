import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snack_bar.dart';

final RegExp _fpEmailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool _isStrongPw(String p) =>
    p.length >= 8 && p.contains(RegExp(r'[a-zA-Z]')) && p.contains(RegExp(r'\d'));

enum _Step { email, reset, done }

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  _Step _step = _Step.email;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ── Step 1: send code ────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final String email = _email.text.trim();
    if (email.isEmpty) { AppSnackBar.showWarning(context, 'auth.fields_required'.tr()); return; }
    if (!_fpEmailRe.hasMatch(email)) { AppSnackBar.showWarning(context, 'auth.email_invalid'.tr()); return; }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post(
        '/auth/forgot-password',
        body: <String, String>{'email': email},
      );
    } catch (_) {
      // Always advance — don't reveal whether email exists
    } finally {
      if (mounted) setState(() { _busy = false; _step = _Step.reset; });
    }
  }

  // ── Step 2: verify code + set new password ───────────────────────────────

  Future<void> _resetPassword() async {
    final String code = _code.text.trim();
    if (code.length != 6) { AppSnackBar.showWarning(context, 'auth.code_invalid'.tr()); return; }
    if (!_isStrongPw(_password.text)) { AppSnackBar.showWarning(context, 'auth.password_weak'.tr()); return; }
    if (_password.text != _confirm.text) { AppSnackBar.showWarning(context, 'auth.passwords_mismatch'.tr()); return; }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post(
        '/auth/reset-password',
        body: <String, dynamic>{
          'email': _email.text.trim(),
          'code': code,
          'new_password': _password.text,
        },
      );
      if (mounted) setState(() { _busy = false; _step = _Step.done; });
    } catch (e) {
      if (mounted) { AppSnackBar.showError(context, e); setState(() => _busy = false); }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.forgot_password'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: switch (_step) {
          _Step.email => _EmailStep(email: _email, busy: _busy, onSubmit: _sendCode),
          _Step.reset => _ResetStep(
              email: _email.text.trim(),
              code: _code,
              password: _password,
              confirm: _confirm,
              codeFocus: _codeFocus,
              obscure: _obscure,
              busy: _busy,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onResend: () => setState(() => _step = _Step.email),
              onSubmit: _resetPassword,
            ),
          _Step.done => _DoneStep(onBack: () => Navigator.of(context).pop()),
        },
      ),
    );
  }
}

// ── Step widgets ─────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  const _EmailStep({required this.email, required this.busy, required this.onSubmit});
  final TextEditingController email;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Icon(Icons.lock_reset_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('auth.forgot_password_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('auth.forgot_password_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !busy,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'auth.email'.tr(),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox.square(dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('auth.send_reset_link'.tr()),
        ),
      ],
    );
  }
}

class _ResetStep extends StatelessWidget {
  const _ResetStep({
    required this.email, required this.code, required this.password,
    required this.confirm, required this.codeFocus, required this.obscure,
    required this.busy, required this.onToggleObscure,
    required this.onResend, required this.onSubmit,
  });
  final String email;
  final TextEditingController code, password, confirm;
  final FocusNode codeFocus;
  final bool obscure, busy;
  final VoidCallback onToggleObscure, onResend, onSubmit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        Icon(Icons.mark_email_read_rounded, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        Text('auth.reset_code_sent'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('auth.reset_code_sent_hint'.tr(args: <String>[email]),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),
        TextField(
          controller: code,
          focusNode: codeFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          enabled: !busy,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 10),
          decoration: InputDecoration(
            labelText: 'auth.reset_code'.tr(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'auth.password'.tr(),
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: onToggleObscure,
            ),
            helperText: 'auth.password_requirements'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: confirm,
          obscureText: obscure,
          enabled: !busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'auth.password_confirm'.tr(),
            prefixIcon: const Icon(Icons.lock_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox.square(dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('auth.set_new_password'.tr()),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onResend,
          child: Text('auth.resend_code'.tr()),
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 48),
        Icon(Icons.check_circle_rounded, size: 72,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text('auth.password_reset_success'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('auth.password_reset_success_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onBack,
          child: Text('auth.back_to_login'.tr()),
        ),
      ],
    );
  }
}
