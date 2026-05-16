import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';

// ─── APK-matching "СМЫСЛ" feature card ──────────────────────────────────────

class _SmyshlCard extends StatelessWidget {
  const _SmyshlCard({
    required this.number,
    required this.emoji1,
    required this.emoji2,
    required this.title,
    required this.description,
  });

  final int number;
  final String emoji1;
  final String emoji2;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      color: kChildSurfaceWhite,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kChildAccentOrange,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 7),
              Text(
                'СМЫСЛ $number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3ECF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text('$emoji1$emoji2', style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kChildBrandBlue,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kChildInkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── APK-style text field decoration ────────────────────────────────────────

/// Wraps a child (e.g. TextField) in a soft-shadowed pill-shaped container
/// to match Figma input styling.
class SoftInputContainer extends StatelessWidget {
  const SoftInputContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2D52).withValues(alpha: 0.10),
            offset: const Offset(0, 6),
            blurRadius: 18,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}

InputDecoration _authInput(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kChildInkMuted, fontSize: 15),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
    ),
    suffixIcon: suffixIcon,
  );
}

// ─── Parent sign-in page ─────────────────────────────────────────────────────

class ParentSignInPage extends ConsumerStatefulWidget {
  const ParentSignInPage({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  ConsumerState<ParentSignInPage> createState() => _ParentSignInPageState();
}

class _ParentSignInPageState extends ConsumerState<ParentSignInPage> {
  static const _kBiometricLogin = 'biometric_login';
  static const _kBiometricPassword = 'biometric_password';

  int _step = 0; // 0 = email, 1 = password
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = LocalAuthentication();
  bool _busy = false;
  bool _obscure = true;
  bool _biometricReady = false;
  String? _savedLogin;
  String? _savedPassword;

  Future<void> _proceed() async {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите email или телефон')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    if (kIsWeb) return;

    try {
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
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _biometricReady = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricReady = false);
    }
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите пароль')),
      );
      return;
    }
    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните .env (API_BASE_URL) чтобы войти')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).parentSignIn(
            login: _email.text.trim(),
            password: _password.text,
            inviteToken: '',
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBiometricLogin, _email.text.trim());
      await prefs.setString(_kBiometricPassword, _password.text);
      if (mounted) context.go('/parent');
    } catch (_) {
      // Sign-in failed → automatically register
      try {
        await ref.read(authActionsProvider).parentSignUp(
              phone: _email.text.trim(),
              password: _password.text,
              recoveryEmail: _email.text.trim(),
            );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kBiometricLogin, _email.text.trim());
        await prefs.setString(_kBiometricPassword, _password.text);
        if (mounted) context.go('/parent');
      } catch (signUpError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $signUpError')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithBiometric() async {
    if (kIsWeb || _busy || !_biometricReady) return;
    setState(() => _busy = true);
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Подтвердите вход в приложение',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return;
      await ref.read(authActionsProvider).parentSignIn(
            login: _savedLogin ?? '',
            password: _savedPassword ?? '',
            inviteToken: '',
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

  @override
  Widget build(BuildContext context) {
    final isEmailStep = _step == 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kChildInk),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        centerTitle: true,
        title: const Text(
          'Регистрация',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            // Hero illustration card
            _AuthHeroCard(
              asset: isEmailStep
                  ? 'assets/figma/hero_birzha.png'
                  : 'assets/figma/hero_economika.png',
              bg: isEmailStep ? kBrandLavender : kBrandSunny,
              title: isEmailStep ? 'Биржа задач' : 'Лимиты и Капитал',
              subtitle: isEmailStep
                  ? 'Создавай задания и назначай оплату участникам'
                  : 'Устанавливай лимиты и управляй капиталом',
            ),
            const SizedBox(height: 28),
            // Step-specific content
            if (isEmailStep) ...[
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 10),
                child: Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
              ),
              SoftInputContainer(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  decoration: _authInput('email@gmail.com'),
                  style: const TextStyle(fontSize: 15, color: kChildInk),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _proceed,
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandMint,
                    foregroundColor: const Color(0xFF000000),
                    minimumSize: const Size.fromHeight(56),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Продолжить',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 10),
                child: Text(
                  'Пароль',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
              ),
              StatefulBuilder(
                builder: (context, setLocal) => SoftInputContainer(
                  child: TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: _authInput(
                      '••••••••',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kChildInkMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    style: const TextStyle(fontSize: 15, color: kChildInk),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandMint,
                    foregroundColor: const Color(0xFF000000),
                    minimumSize: const Size.fromHeight(56),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1F4F1B),
                          ),
                        )
                      : const Text(
                          'Войти в управление',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => context.go('/auth/recover'),
                  style: TextButton.styleFrom(foregroundColor: kChildInkMuted),
                  child: const Text(
                    'Забыли пароль?',
                    style: TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthHeroCard extends StatelessWidget {
  const _AuthHeroCard({
    required this.asset,
    required this.bg,
    required this.title,
    required this.subtitle,
  });
  final String asset;
  final Color bg;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.05,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => Container(color: bg),
      ),
    );
  }
}

// ─── Activation key display (post-registration) ──────────────────────────────

class ParentActivationKeyPage extends StatelessWidget {
  const ParentActivationKeyPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kChildSurfaceSoft,
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'CLAN CAPITAL',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: kChildBrandBlue,
                          letterSpacing: 1.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Глава Клана',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kChildInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ChildSoftCard(
              color: kChildSurfaceWhite,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3ECF8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🔑📱', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _PlayBadge(),
                            SizedBox(width: 7),
                            Text(
                              'СМЫСЛ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kChildInk,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Чтобы ребёнок увидел свою Биржу, поделитесь этим Ключом активации',
                          style: TextStyle(
                            fontSize: 14,
                            color: kChildInkMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ChildSoftCard(
              color: kChildSurfaceWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: kChildBrandBlue,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/parent'),
                style: FilledButton.styleFrom(
                  backgroundColor: kChildBrandBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'ПЕРЕЙТИ НА ГЛАВНЫЙ ЭКРАН',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/parent'),
                style: TextButton.styleFrom(foregroundColor: kChildBrandBlue),
                child: const Text(
                  'Показать позже',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: kChildAccentOrange,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
    );
  }
}
