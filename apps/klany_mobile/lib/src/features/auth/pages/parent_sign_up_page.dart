import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../password_rules.dart';

class ParentSignUpPage extends ConsumerStatefulWidget {
  const ParentSignUpPage({super.key});

  @override
  ConsumerState<ParentSignUpPage> createState() => _ParentSignUpPageState();
}

class _ParentSignUpPageState extends ConsumerState<ParentSignUpPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  static const _avatars = ['🧒', '👧', '👦', '👩', '👨', '🧑'];
  String _selectedAvatar = '🧒';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Заполните имя и телефон')),
      );
      return;
    }
    final pwErr = KlanyPasswordRules.validatePlain(_password.text);
    if (pwErr != null) {
      context.showKlanySnackBar(SnackBar(content: Text(pwErr)));
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
      await ref.read(authActionsProvider).parentSignUp(
            phone: _phone.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            recoveryEmail: _email.text.trim(),
          );
      if (!mounted) return;
      context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openAvatarSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kChildSurfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Выбор аватара',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kChildInk,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _avatars.map((a) {
                  final sel = _selectedAvatar == a;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatar = a);
                      Navigator.pop(sheetCtx);
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kChildSurfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? kChildBrandBlue : kChildOutline,
                          width: sel ? 2.4 : 1.4,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: kChildBrandBlue.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(a, style: const TextStyle(fontSize: 30)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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
                  navTitle: 'Регистрация',
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
                      dotCount: 2,
                      activeDotIndex: 0,
                    ),
                    form: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                        child: Text('Имя участника', style: kFigmaAuthFieldLabelStyle),
                      ),
                      FigmaAuthInputShell(
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          style: kFigmaAuthInputTextStyle,
                          decoration:
                              figmaAuthFieldDecoration('Как к тебе обращаться'),
                        ),
                      ),
                      const SizedBox(height: kFigmaAuthFieldStackGap),
                      const Padding(
                        padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                        child: Text('Выбор аватара', style: kFigmaAuthFieldLabelStyle),
                      ),
                      Row(
                        children: [
                          ..._avatars.take(3).map((a) {
                            final sel = _selectedAvatar == a;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedAvatar = a),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: kChildSurfaceWhite,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          sel ? kChildBrandBlue : kChildOutline,
                                      width: sel ? 2.4 : 1.4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child:
                                      Text(a, style: const TextStyle(fontSize: 30)),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: _openAvatarSheet,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: kChildSurfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: kChildOutline,
                                  width: 1.4,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.add,
                                color: kChildInkMuted,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kFigmaAuthFieldStackGap),
                      const Padding(
                        padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                        child: Text('Телефон', style: kFigmaAuthFieldLabelStyle),
                      ),
                      FigmaAuthInputShell(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          style: kFigmaAuthInputTextStyle,
                          decoration:
                              figmaAuthFieldDecoration('+7 (999) 000-00-00'),
                        ),
                      ),
                      const SizedBox(height: kFigmaAuthFieldStackGap),
                      const Padding(
                        padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                        child: Text('Email', style: kFigmaAuthFieldLabelStyle),
                      ),
                      FigmaAuthInputShell(
                        child: TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: kFigmaAuthInputTextStyle,
                          decoration: figmaAuthFieldDecoration('email@gmail.com'),
                        ),
                      ),
                      const SizedBox(height: kFigmaAuthFieldStackGap),
                      const Padding(
                        padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                        child: Text('Пароль', style: kFigmaAuthFieldLabelStyle),
                      ),
                      FigmaAuthInputShell(
                        child: TextField(
                          controller: _password,
                          obscureText: _obscure,
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
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 6),
                        child: Text(
                          'Минимум 8 символов. Латиница или кириллица, цифры, '
                          r'символы !@#$%^&*()_+-=[]{}|;:,./?',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: kChildInkMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: kFigmaAuthBeforePrimaryCtaGap),
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
                          label: 'ПРИНЯТЬ В КЛАН',
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
                      const SizedBox(height: kFigmaAuthFieldStackGap),
                      Center(
                        child: TextButton(
                          onPressed:
                              _busy ? null : () => context.go('/auth/parent/sign-in'),
                          style: TextButton.styleFrom(
                            foregroundColor: kChildBrandBlue,
                          ),
                          child: const Text(
                            'Уже есть аккаунт? Войти',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationThickness: 1.2,
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
