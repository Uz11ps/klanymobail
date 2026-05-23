import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../../theme/klany_figma_style.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../password_rules.dart';

/// Ввод 6-значного кода из письма и нового пароля (только в приложении).
class ForgotPasswordCodePage extends ConsumerStatefulWidget {
  const ForgotPasswordCodePage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ForgotPasswordCodePage> createState() =>
      _ForgotPasswordCodePageState();
}

class _ForgotPasswordCodePageState extends ConsumerState<ForgotPasswordCodePage> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (!Env.hasApiConfig) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authActionsProvider)
          .requestPasswordReset(email: widget.email);
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Новый код отправлен на почту')),
      );
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final code = _code.text.trim().replaceAll(RegExp(r'\s'), '');
    if (code.length != 6) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите 6-значный код из письма')),
      );
      return;
    }
    final err = KlanyPasswordRules.validatePlain(_password.text);
    if (err != null) {
      context.showKlanySnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }
    if (!Env.hasApiConfig) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('API не настроен')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).resetPassword(
            email: widget.email,
            code: code,
            password: _password.text,
          );
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(
          content: Text('Пароль обновлён. Войдите с новым паролем'),
        ),
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
                  navTitle: 'Новый пароль',
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/auth/forgot-password');
                    }
                  },
                ),
                Expanded(
                  child: FigmaAuthPageBody(
                    hero: const FigmaAuthHero(
                      asset: 'assets/figma/hero_economika.png',
                      showDots: true,
                      dotCount: 3,
                      activeDotIndex: 1,
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: kFigmaAuthLabelToFieldGap,
                          ),
                          child: Text(
                            'Код из письма\n${widget.email}',
                            style: kFigmaAuthFieldLabelStyle,
                          ),
                        ),
                        FigmaAuthInputShell(
                          child: TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: kFigmaAuthInputTextStyle.copyWith(
                              fontSize: 22,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: figmaAuthFieldDecoration('000000'),
                          ),
                        ),
                        const SizedBox(height: kFigmaAuthFieldStackGap),
                        const Padding(
                          padding: EdgeInsets.only(
                            bottom: kFigmaAuthLabelToFieldGap,
                          ),
                          child: Text(
                            'Новый пароль',
                            style: kFigmaAuthFieldLabelStyle,
                          ),
                        ),
                        FigmaAuthInputShell(
                          child: TextField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            style: kFigmaAuthInputTextStyle,
                            decoration: figmaAuthFieldDecoration(
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
                        const Padding(
                          padding: EdgeInsets.only(
                            bottom: kFigmaAuthLabelToFieldGap,
                          ),
                          child: Text(
                            'Подтверждение',
                            style: kFigmaAuthFieldLabelStyle,
                          ),
                        ),
                        FigmaAuthInputShell(
                          child: TextField(
                            controller: _passwordConfirm,
                            obscureText: _obscureConfirm,
                            style: kFigmaAuthInputTextStyle,
                            decoration: figmaAuthFieldDecoration(
                              '••••••••',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: kChildInkMuted,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
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
                            label: 'Сохранить пароль',
                            gradient: FigmaGradientButton.mintGradientVertical,
                            height: kFigmaAuthPrimaryCtaHeight,
                            labelStyle: kFigmaLandingCtaTextStyle,
                            boxShadow: kFigmaLandingCtaBoxShadows,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            onTap: _submit,
                          ),
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _resend,
                            style: TextButton.styleFrom(
                              foregroundColor: kChildBrandBlue,
                            ),
                            child: const Text(
                              'Отправить код ещё раз',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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
