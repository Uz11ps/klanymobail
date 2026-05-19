import 'dart:math' as math;

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
import '../phone_utils.dart';
import '../../../core/app_snackbar.dart';

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
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 14,
                ),
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
                child: Text(
                  '$emoji1$emoji2',
                  style: const TextStyle(fontSize: 28),
                ),
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

InputDecoration _authInput(String hint, {Widget? suffixIcon}) =>
    figmaAuthFieldDecoration(hint, suffixIcon: suffixIcon);

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
    final err = validateParentLoginIdentifier(_email.text);
    if (err != null) {
      context.showKlanySnackBar(SnackBar(content: Text(err)));
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
        _biometricReady =
            canUse &&
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
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите пароль')),
      );
      return;
    }
    final loginErr = validateParentLoginIdentifier(_email.text);
    if (loginErr != null) {
      context.showKlanySnackBar(SnackBar(content: Text(loginErr)));
      return;
    }
    if (!Env.hasApiConfig) {
      context.showKlanySnackBar(
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
            login: _email.text.trim(),
            password: _password.text,
            inviteToken: '',
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBiometricLogin, _email.text.trim());
      await prefs.setString(_kBiometricPassword, _password.text);
      if (mounted) context.go('/parent');
    } catch (_) {
      // Sign-in failed → automatically register (email в API — только в email/recovery, не в phone)
      try {
        final login = _email.text.trim();
        final asEmail = login.contains('@');
        await ref
            .read(authActionsProvider)
            .parentSignUp(
              phone: asEmail ? '' : login,
              password: _password.text,
              recoveryEmail: asEmail ? login : null,
            );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kBiometricLogin, _email.text.trim());
        await prefs.setString(_kBiometricPassword, _password.text);
        if (mounted) context.go('/parent');
      } catch (signUpError) {
        if (!mounted) return;
        context.showKlanySnackBar(
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
            inviteToken: '',
          );
      if (mounted) context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка биометрии: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmailStep = _step == 0;

    void onBack() {
      if (_step == 1) {
        setState(() => _step = 0);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/auth');
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FigmaAuthScreenBackground(),
          Padding(
            padding: EdgeInsets.only(
              top: math.max(
                MediaQuery.paddingOf(context).top,
                kFigmaLandingMinTopInset,
              ),
              bottom: math.max(
                MediaQuery.paddingOf(context).bottom,
                kFigmaLandingMinBottomInset,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FigmaAuthDoubleDeckHeader(
                  navTitle: 'Регистрация',
                  onBack: onBack,
                ),
                Expanded(
                  child: FigmaAuthPageBody(
                    hero: FigmaAuthHero(
                      asset: isEmailStep
                          ? 'assets/figma/hero_birzha.png'
                          : 'assets/figma/hero_economika.png',
                      fallbackColor: isEmailStep ? kBrandLavender : kBrandSunny,
                      showDots: true,
                      dotCount: 3,
                      activeDotIndex: _step.clamp(0, 2),
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isEmailStep) ...[
                          const Padding(
                            padding: EdgeInsets.only(
                              bottom: kFigmaAuthLabelToFieldGap,
                            ),
                            child: Text(
                              'Email',
                              style: kFigmaAuthFieldLabelStyle,
                            ),
                          ),
                          FigmaAuthInputShell(
                            child: TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              style: kFigmaAuthInputTextStyle,
                              decoration: _authInput('email@gmail.com'),
                            ),
                          ),
                          const SizedBox(height: kFigmaAuthFieldStackGap),
                          FigmaGradientButton(
                            label: 'Продолжить',
                            gradient: FigmaGradientButton.mintGradientVertical,
                            height: kFigmaAuthPrimaryCtaHeight,
                            labelStyle: kFigmaLandingCtaTextStyle,
                            boxShadow: kFigmaLandingCtaBoxShadows,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            onTap: _busy ? null : _proceed,
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.only(
                              bottom: kFigmaAuthLabelToFieldGap,
                            ),
                            child: Text(
                              'Пароль',
                              style: kFigmaAuthFieldLabelStyle,
                            ),
                          ),
                          FigmaAuthInputShell(
                            child: TextField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              style: kFigmaAuthInputTextStyle,
                              decoration: _authInput(
                                '••••••••',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: kChildInkMuted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: kFigmaAuthFieldStackGap),
                          if (_busy)
                            const SizedBox(
                              height: kFigmaAuthPrimaryCtaHeight,
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF1F4F1B),
                                  ),
                                ),
                              ),
                            )
                          else
                            FigmaGradientButton(
                              label: 'Войти в управление',
                              gradient:
                                  FigmaGradientButton.mintGradientVertical,
                              height: kFigmaAuthPrimaryCtaHeight,
                              labelStyle: kFigmaLandingCtaTextStyle,
                              boxShadow: kFigmaLandingCtaBoxShadows,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              onTap: _submit,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      backgroundColor: Colors.transparent,
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
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: 0.4,
                  ),
                ),
                child: const Text('ПЕРЕЙТИ НА ГЛАВНЫЙ ЭКРАН'),
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
