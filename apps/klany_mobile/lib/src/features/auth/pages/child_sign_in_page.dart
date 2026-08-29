import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/family_access_code.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../child_session.dart';
import '../device_identity.dart';

InputDecoration _authInput(String hint, {Widget? suffixIcon}) =>
    figmaAuthFieldDecoration(hint, suffixIcon: suffixIcon);

/// Вход участника семьи по 8-значному ключу (ребёнок или взрослый).
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
    if (!isValidFamilyAccessCode(authCode)) {
      context.showKlanySnackBar(
        SnackBar(
          content: Text(
            'Введите $kFamilyAccessCodeLength-значный код участника',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      // Сначала взрослый участник (мама/папа/…), затем ребёнок — один экран для всех.
      try {
        await ref.read(authActionsProvider).parentSignInByCode(code: authCode);
        if (!mounted) return;
        context.go('/parent');
        return;
      } on ApiException catch (e) {
        final tryChild = e.statusCode == 401 ||
            (e.statusCode == 403 &&
                e.message.toLowerCase().contains('ребён'));
        if (!tryChild) rethrow;
      }

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
      context.showKlanyErrorSnackBar(e);
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
                navTitle: 'Регистрация',
                onBack: onBack,
                embeddedInPage: true,
              ),
              hero: const FigmaAuthHero(
                      asset: 'assets/figma/hero_flag.png',
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
                            '8 цифр — код участника семьи от Главы Клана',
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
                            maxLength: kFamilyAccessCodeInputMaxLength,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                kFamilyAccessCodeInputMaxLength,
                              ),
                            ],
                            obscureText: _obscure,
                            decoration: _authInput(
                              kFamilyAccessCodeDigitsHint,
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
    );
  }
}
