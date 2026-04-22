import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';

class ParentSignUpPage extends ConsumerStatefulWidget {
  const ParentSignUpPage({super.key});

  @override
  ConsumerState<ParentSignUpPage> createState() => _ParentSignUpPageState();
}

class _ParentSignUpPageState extends ConsumerState<ParentSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _recoveryEmail = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _recoveryEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните .env (API_BASE_URL) чтобы зарегистрироваться'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).parentSignUp(
            phone: _phone.text,
            password: _password.text,
            displayName: _name.text,
            recoveryEmail: _recoveryEmail.text,
          );
      if (!mounted) return;
      context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка регистрации: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Пользователь: регистрация',
      subtitle:
          'Создайте родительский аккаунт по телефону. Email нужен для входа в веб-админку.',
      children: [
        Form(
          key: _formKey,
          child: ChildSoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: clanInputDecoration(
                    label: 'Имя (необязательно)',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: clanInputDecoration(
                    label: 'Телефон',
                    icon: Icons.phone,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Введите телефон';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recoveryEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: clanInputDecoration(
                    label: 'Email для входа в веб-админку',
                    icon: Icons.email,
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
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: clanInputDecoration(
                    label: 'Пароль',
                    icon: Icons.lock,
                    hint: 'Минимум 6 символов',
                  ),
                  validator: (v) =>
                      (v ?? '').length < 6 ? 'Минимум 6 символов' : null,
                ),
                const SizedBox(height: 18),
                ClanPrimaryButton(
                  label: _busy ? 'Создаём...' : 'Создать аккаунт',
                  icon: Icons.check_circle,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
