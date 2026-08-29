import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../../theme/klany_figma_style.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../password_rules.dart';

/// Шаг 2: новый пароль (только после проверки кода на API).
class ForgotPasswordNewPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordNewPasswordPage({
    super.key,
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  @override
  ConsumerState<ForgotPasswordNewPasswordPage> createState() =>
      _ForgotPasswordNewPasswordPageState();
}

class _ForgotPasswordNewPasswordPageState
    extends ConsumerState<ForgotPasswordNewPasswordPage> {
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
            code: widget.code,
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
      context.showKlanyErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FigmaAuthScreenBackground(),
          Padding(
            padding: EdgeInsets.only(
              top: math.max(
                MediaQuery.paddingOf(context).top,
                kFigmaAuthMinTopInset,
              ),
              bottom: math.max(
                MediaQuery.paddingOf(context).bottom,
                kFigmaLandingMinBottomInset,
              ),
            ),
            child: FigmaAuthPageBody(
              header: FigmaAuthDoubleDeckHeader(
                navTitle: 'Новый пароль',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(
                      '/auth/forgot-password/code?email=${Uri.encodeComponent(widget.email)}',
                    );
                  }
                },
                embeddedInPage: true,
              ),
              hero: const FigmaAuthHero(
                      asset: 'assets/figma/hero_economika.png',
                      showDots: true,
                      dotCount: 3,
                      activeDotIndex: 2,
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
