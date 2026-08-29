import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';

/// Ссылка под CTA на экранах входа.
class ForgotPasswordLink extends StatelessWidget {
  const ForgotPasswordLink({super.key, this.prefillEmail = ''});

  final String prefillEmail;

  void _open(BuildContext context) {
    final email = prefillEmail.trim();
    if (email.contains('@')) {
      context.push('/auth/forgot-password?email=${Uri.encodeComponent(email)}');
    } else {
      context.push('/auth/forgot-password');
    }
  }

  /// После отправки кода — сразу экран ввода (если email уже известен).
  static void openCodeStep(BuildContext context, String email) {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      context.push('/auth/forgot-password');
      return;
    }
    context.push(
      '/auth/forgot-password/code?email=${Uri.encodeComponent(trimmed)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: TextButton(
          onPressed: () => _open(context),
          style: TextButton.styleFrom(
            foregroundColor: kChildBrandBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text(
            'Забыли пароль?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
