import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../../../core/sdk.dart';
import '../admin_session.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final api = Sdk.apiOrNull;
    if (!Env.hasApiConfig || api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните apps/klany_admin/.env (API_BASE_URL)')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await api.postJson(
        '/auth/sign-in',
        body: <String, dynamic>{
          'email': _email.text.trim(),
          'password': _password.text,
        },
      );
      final accessToken = (res['accessToken'] ?? '').toString();
      final user = (res['user'] as Map?) ?? const <String, dynamic>{};
      final profile = (res['profile'] as Map?) ?? const <String, dynamic>{};
      final userId = (user['id'] ?? '').toString();
      final role = (profile['role'] ?? '').toString();

      if (accessToken.isEmpty || userId.isEmpty) {
        throw Exception('Пустой accessToken/userId');
      }
      if (role != 'admin') {
        throw Exception('Нет доступа: требуется роль admin');
      }

      await ref.read(adminSessionProvider.notifier).setSession(
            AdminSession(accessToken: accessToken, userId: userId, role: role),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Klany Admin', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
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
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) {
                        final value = (v ?? '');
                        if (value.isEmpty) return 'Введите пароль';
                        // Админка может использовать короткий пароль на первом деплое (сид).
                        if (value.length < 3) return 'Минимум 3 символа';
                        return null;
                      },
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
                    Text(
                      'Доступ только для role=admin (JWT).',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

