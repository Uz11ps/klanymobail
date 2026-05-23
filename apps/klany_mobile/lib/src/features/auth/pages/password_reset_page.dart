import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../password_rules.dart';

/// Сброс пароля по токену из письма Resend.
class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key, this.initialToken = ''});

  final String initialToken;

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken.trim());
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      context.showKlanySnackBar(const SnackBar(content: Text('Вставьте токен из письма')));
      return;
    }
    final err = KlanyPasswordRules.validatePlain(_password.text);
    if (err != null) {
      context.showKlanySnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      context.showKlanySnackBar(const SnackBar(content: Text('Пароли не совпадают')));
      return;
    }
    if (!Env.hasApiConfig) {
      context.showKlanySnackBar(const SnackBar(content: Text('API не настроен')));
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).resetPassword(
            token: token,
            password: _password.text,
          );
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Пароль обновлён. Войдите с новым паролем')),
      );
      context.go('/auth/parent/sign-in');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = kChildInk;
    const labelColor = Color(0xFFB0BDD6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/auth/recover'),
        ),
        title: const Text(
          'Новый пароль',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _token,
                style: const TextStyle(fontFamily: 'Nunito', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Токен из письма',
                  labelStyle: TextStyle(color: labelColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3A4F72)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kChildBrandBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _password,
                obscureText: _obscure,
                style: const TextStyle(fontFamily: 'Nunito', color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  labelStyle: const TextStyle(color: labelColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: labelColor,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3A4F72)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kChildBrandBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordConfirm,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontFamily: 'Nunito', color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Подтверждение',
                  labelStyle: const TextStyle(color: labelColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: labelColor,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3A4F72)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kChildBrandBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6FD0),
                  foregroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить пароль'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
