import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../home/child_soft_ui.dart';
import '../child_session.dart';
import '../device_identity.dart';

InputDecoration _authInput(String hint, {Widget? suffixIcon}) =>
    figmaAuthFieldDecoration(hint, suffixIcon: suffixIcon);

/// Регистрация участника по 6-значному ключу (Figma node 0-1215).
class ChildSignInPage extends ConsumerStatefulWidget {
  const ChildSignInPage({super.key});

  @override
  ConsumerState<ChildSignInPage> createState() => _ChildSignInPageState();
}

class _ChildSignInPageState extends ConsumerState<ChildSignInPage> {
  final _authCode = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _authCode.dispose();
    super.dispose();
  }

  Future<void> _codeSignIn() async {
    final authCode = _authCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(authCode)) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите 6-значный код участника')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final result = await ref
          .read(passwordlessChildRepositoryProvider)
          .signInWithAuthCode(authCode: authCode, device: device);
      if (!mounted) return;
      await ref
          .read(childSessionProvider.notifier)
          .activateFromApproval(
            childId: result.childId,
            familyId: result.familyId,
            childDisplayName: result.childDisplayName,
            accessToken: result.accessToken,
            avatarObjectKey: result.avatarObjectKey,
          );
      if (mounted) context.go('/child');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void onBack() {
      if (context.canPop()) {
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
                    hero: const FigmaAuthHero(
                      asset: 'assets/figma/hero_flag.png',
                      fallbackColor: kBrandSky,
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Ввод ключа',
                            style: kFigmaAuthFieldLabelStyle,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '6 цифр — персональный код от Главы Клана',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kChildInkMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        FigmaAuthInputShell(
                          child: TextField(
                            controller: _authCode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            obscureText: _obscure,
                            decoration: _authInput(
                              '000000',
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
                            ).copyWith(counterText: ''),
                            style: kFigmaAuthInputTextStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            onTap: _busy ? null : _codeSignIn,
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
