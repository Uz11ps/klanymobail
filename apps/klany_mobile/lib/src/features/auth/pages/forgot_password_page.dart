import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../../theme/klany_figma_style.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';

/// Запрос письма со ссылкой на сброс пароля (Resend).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final TextEditingController _email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите корректный email')),
      );
      return;
    }
    if (!Env.hasApiConfig) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Заполните .env (API_BASE_URL)')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).requestPasswordReset(email: email);
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(
          content: Text(
            'Если email зарегистрирован — придёт письмо со ссылкой на сброс пароля',
          ),
        ),
      );
      context.pop();
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
                  navTitle: 'Восстановление',
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/auth/parent/sign-in');
                    }
                  },
                ),
                Expanded(
                  child: FigmaAuthPageBody(
                    hero: const FigmaAuthHero(
                      asset: 'assets/figma/hero_birzha.png',
                      showDots: true,
                      dotCount: 3,
                      activeDotIndex: 0,
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                          child: Text(
                            'Email',
                            style: kFigmaAuthFieldLabelStyle,
                          ),
                        ),
                        FigmaAuthInputShell(
                          child: TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            style: kFigmaAuthInputTextStyle,
                            decoration: figmaAuthFieldDecoration('email@gmail.com'),
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
                            label: 'Отправить письмо',
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
          ),
        ],
      ),
    );
  }
}
