import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../auth_actions.dart';

class ParentSignInPage extends ConsumerStatefulWidget {
  const ParentSignInPage({super.key});

  @override
  ConsumerState<ParentSignInPage> createState() => _ParentSignInPageState();
}

class _ParentSignInPageState extends ConsumerState<ParentSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _inviteToken = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _inviteToken.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните .env (API_BASE_URL) чтобы войти')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).parentSignIn(
            email: _email.text,
            password: _password.text,
          );
      // TODO: acceptParentInvite is not implemented in API yet.
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Родитель: вход')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Введите email';
                      if (!value.contains('@')) return 'Некорректный email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) =>
                        (v ?? '').length < 6 ? 'Минимум 6 символов' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _inviteToken,
                    decoration: const InputDecoration(
                      labelText: 'Токен приглашения (если есть)',
                      prefixIcon: Icon(Icons.group_add),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/auth/parent/sign-up'),
                    child: const Text('Создать аккаунт родителя'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

