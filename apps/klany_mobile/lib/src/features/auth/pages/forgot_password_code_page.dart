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

/// Шаг 1: только код из письма.
class ForgotPasswordCodePage extends ConsumerStatefulWidget {
  const ForgotPasswordCodePage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ForgotPasswordCodePage> createState() =>
      _ForgotPasswordCodePageState();
}

class _ForgotPasswordCodePageState extends ConsumerState<ForgotPasswordCodePage> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
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

  Future<void> _continue() async {
    final code = _code.text.trim().replaceAll(RegExp(r'\s'), '');
    if (code.length != 6) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите 6-значный код из письма')),
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
      await ref.read(authActionsProvider).verifyPasswordResetCode(
            email: widget.email,
            code: code,
          );
      if (!mounted) return;
      context.push(
        '/auth/forgot-password/new-password',
        extra: <String, String>{
          'email': widget.email,
          'code': code,
        },
      );
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
                kFigmaAuthMinTopInset,
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
                  navTitle: 'Код из письма',
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
                      asset: 'assets/figma/hero_birzha.png',
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: kFigmaAuthInputTextStyle.copyWith(
                              fontSize: 22,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: figmaAuthFieldDecoration(
                              '000000',
                            ).copyWith(counterText: ''),
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
                            label: 'Продолжить',
                            gradient: FigmaGradientButton.mintGradientVertical,
                            height: kFigmaAuthPrimaryCtaHeight,
                            labelStyle: kFigmaLandingCtaTextStyle,
                            boxShadow: kFigmaLandingCtaBoxShadows,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            onTap: _continue,
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
