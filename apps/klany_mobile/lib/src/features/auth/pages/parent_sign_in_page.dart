import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/env.dart';
import '../auth_actions.dart';

class ParentSignInPage extends ConsumerStatefulWidget {
  const ParentSignInPage({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  ConsumerState<ParentSignInPage> createState() => _ParentSignInPageState();
}

class _ParentSignInPageState extends ConsumerState<ParentSignInPage> {
  static const _kBiometricLogin = 'biometric_login';
  static const _kBiometricPassword = 'biometric_password';
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _accessCode = TextEditingController();
  final _inviteToken = TextEditingController();
  final _auth = LocalAuthentication();
  bool _busy = false;
  bool _saveForBiometric = false;
  bool _biometricReady = false;
  String? _savedLogin;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _accessCode.dispose();
    _inviteToken.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final canUse =
        await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    final savedLogin = prefs.getString(_kBiometricLogin);
    final savedPassword = prefs.getString(_kBiometricPassword);
    if (!mounted) return;
    setState(() {
      _biometricReady =
          canUse &&
          (savedLogin ?? '').isNotEmpty &&
          (savedPassword ?? '').isNotEmpty;
      _savedLogin = savedLogin;
      _savedPassword = savedPassword;
    });
  }

  Future<void> _saveBiometricCreds() async {
    final prefs = await SharedPreferences.getInstance();
    if (_saveForBiometric) {
      await prefs.setString(_kBiometricLogin, _login.text.trim());
      await prefs.setString(_kBiometricPassword, _password.text);
    }
  }

  Future<void> _signInWithBiometric() async {
    if (_busy || !_biometricReady) return;
    setState(() => _busy = true);
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Подтвердите вход в приложение',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return;
      await ref
          .read(authActionsProvider)
          .parentSignIn(
            login: _savedLogin ?? '',
            password: _savedPassword ?? '',
            inviteToken: _inviteToken.text,
          );
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка биометрии: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните .env (API_BASE_URL) чтобы войти'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(authActionsProvider)
          .parentSignIn(
            login: _login.text,
            password: _password.text,
            inviteToken: _inviteToken.text,
          );
      await _saveBiometricCreds();
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка входа: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitByCode() async {
    final code = _accessCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите 6-значный код доступа')),
      );
      return;
    }
    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните .env (API_BASE_URL) чтобы войти'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).parentSignInByCode(code: code);
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка входа по коду: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Администратор: вход' : 'Пользователь: вход',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!widget.isAdmin) ...[
                    TextFormField(
                      controller: _accessCode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Код доступа семьи (6 цифр)',
                        counterText: '',
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _submitByCode,
                        icon: const Icon(Icons.login),
                        label: const Text('Войти по коду доступа'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _login,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                      AutofillHints.telephoneNumber,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Email или телефон',
                      prefixIcon: Icon(
                        widget.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.alternate_email,
                      ),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        return 'Введите email или телефон';
                      }
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
                  if (!widget.isAdmin)
                    TextFormField(
                      controller: _inviteToken,
                      decoration: const InputDecoration(
                        labelText: 'Токен приглашения (если есть)',
                        prefixIcon: Icon(Icons.group_add),
                      ),
                    ),
                  if (!widget.isAdmin) const SizedBox(height: 16),
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
                  if (!widget.isAdmin)
                    CheckboxListTile(
                      value: _saveForBiometric,
                      onChanged: _busy
                          ? null
                          : (v) =>
                                setState(() => _saveForBiometric = v == true),
                      title: const Text('Включить вход по отпечатку/Face ID'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  if (!widget.isAdmin && _biometricReady)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _signInWithBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Войти по биометрии'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/auth/recover'),
                    child: const Text('Восстановление доступа'),
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
