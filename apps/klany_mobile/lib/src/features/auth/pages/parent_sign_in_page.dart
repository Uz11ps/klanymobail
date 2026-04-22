import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
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
      _biometricReady = canUse &&
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
      await ref.read(authActionsProvider).parentSignIn(
            login: _savedLogin ?? '',
            password: _savedPassword ?? '',
            inviteToken: _inviteToken.text,
          );
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка биометрии: $e')),
      );
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
      await ref.read(authActionsProvider).parentSignIn(
            login: _login.text,
            password: _password.text,
            inviteToken: _inviteToken.text,
          );
      await _saveBiometricCreds();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа по коду: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isAdmin ? 'Администратор: вход' : 'Пользователь: вход';
    final subtitle = widget.isAdmin
        ? 'Вход по email или телефону в режиме администратора.'
        : 'Родитель: email/телефон + пароль или код доступа семьи.';

    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: title,
      subtitle: subtitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isAdmin) ...[
                ChildSoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'По коду доступа семьи',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _accessCode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: clanInputDecoration(
                          label: 'Код доступа (6 цифр)',
                          icon: Icons.vpn_key,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClanPrimaryButton(
                        label: 'Войти по коду доступа',
                        icon: Icons.login,
                        busy: _busy,
                        onPressed: _busy ? null : _submitByCode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ChildSoftCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.isAdmin
                          ? 'Вход администратора'
                          : 'По email или телефону',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _login,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                        AutofillHints.telephoneNumber,
                      ],
                      decoration: clanInputDecoration(
                        label: 'Email или телефон',
                        icon: widget.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.alternate_email,
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Введите email или телефон';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: clanInputDecoration(
                        label: 'Пароль',
                        icon: Icons.lock,
                      ),
                      validator: (v) =>
                          (v ?? '').length < 6 ? 'Минимум 6 символов' : null,
                    ),
                    if (!widget.isAdmin) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _inviteToken,
                        decoration: clanInputDecoration(
                          label: 'Токен приглашения (если есть)',
                          icon: Icons.group_add,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ClanPrimaryButton(
                      label: _busy ? 'Входим...' : 'Войти',
                      icon: Icons.login,
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    if (!widget.isAdmin) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _saveForBiometric,
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                  () => _saveForBiometric = v == true,
                                ),
                        title: const Text(
                          'Включить вход по отпечатку/Face ID',
                          style: TextStyle(
                            fontSize: 13,
                            color: kChildInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: kChildBrandBlue,
                      ),
                      if (_biometricReady)
                        ClanSecondaryButton(
                          label: 'Войти по биометрии',
                          icon: Icons.fingerprint,
                          onPressed: _busy ? null : _signInWithBiometric,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed:
                      _busy ? null : () => context.go('/auth/recover'),
                  child: const Text(
                    'Восстановление доступа',
                    style: TextStyle(
                      color: kChildBrandBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
