import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/env.dart';
import '../../../theme/klany_figma_style.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../home/pages/document_page.dart';
import '../auth_actions.dart';
import '../parent_access_repository.dart';
import '../password_rules.dart';
import '../phone_utils.dart';

int _digitsOnlyLength(String raw) =>
    raw.replaceAll(RegExp(r'[^0-9]'), '').length;

/// Figma Frame 123 / узел 0:1283 — круг с иконкой камеры.
const String _chiefPhotoPlaceholderAsset =
    'assets/figma/chief_register_photo.svg';

const double _chiefPhotoDiameter = 112;

/// Полная регистрация главы клана для email, которого ещё нет в системе.
class ParentChiefRegisterPage extends ConsumerStatefulWidget {
  const ParentChiefRegisterPage({
    super.key,
    required this.initialEmail,
  });

  /// Почта, введённая на шаге «Продолжить».
  final String initialEmail;

  @override
  ConsumerState<ParentChiefRegisterPage> createState() =>
      _ParentChiefRegisterPageState();
}

class _ParentChiefRegisterPageState extends ConsumerState<ParentChiefRegisterPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  bool _agreePrivacy = false;
  bool _agreeTerms = false;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _avatarPickedFile;
  Uint8List? _avatarPreviewBytes;

  TapGestureRecognizer? _privacyReco;
  TapGestureRecognizer? _termsReco;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
    _privacyReco = TapGestureRecognizer()
      ..onTap = () =>
          _openDoc('Политика конфиденциальности', privacyPolicyBody);
    _termsReco = TapGestureRecognizer()
      ..onTap = () =>
          _openDoc('Пользовательское соглашение', userAgreementBody);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _privacyReco?.dispose();
    _termsReco?.dispose();
    super.dispose();
  }

  Future<void> _showAvatarSourcePicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: kChildSurfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(sheetCtx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(sheetCtx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await _pickAvatar(
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final img = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (img == null || !mounted) return;
      final bytes = await img.readAsBytes();
      setState(() {
        _avatarPickedFile = img;
        _avatarPreviewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Не удалось выбрать фото: $e')),
      );
    }
  }

  Widget _buildAvatarChip() {
    final bytes = _avatarPreviewBytes;
    return GestureDetector(
      onTap: _busy ? null : _showAvatarSourcePicker,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _chiefPhotoDiameter,
        height: _chiefPhotoDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: _chiefPhotoDiameter,
                height: _chiefPhotoDiameter,
                gaplessPlayback: true,
              )
            : SvgPicture.asset(
                _chiefPhotoPlaceholderAsset,
                width: _chiefPhotoDiameter,
                height: _chiefPhotoDiameter,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  void _openDoc(String title, String body) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => DocumentPage(title: title, body: body),
      ),
    );
  }

  String? _displayNameForSubmit() {
    final n = _name.text.trim();
    if (n.isEmpty) return null;
    return n;
  }

  Future<void> _submit() async {
    final emailErr = validateParentLoginIdentifier(_email.text);
    if (emailErr != null) {
      context.showKlanySnackBar(SnackBar(content: Text(emailErr)));
      return;
    }
    if (_phone.text.trim().isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите номер телефона')),
      );
      return;
    }
    if (_digitsOnlyLength(_phone.text) < 10) {
      context.showKlanySnackBar(
        const SnackBar(
          content: Text('Укажите корректный телефон (не менее 10 цифр)'),
        ),
      );
      return;
    }
    final pwErr = KlanyPasswordRules.validatePlain(_password.text);
    if (pwErr != null) {
      context.showKlanySnackBar(SnackBar(content: Text(pwErr)));
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }
    if (!_agreePrivacy || !_agreeTerms) {
      context.showKlanySnackBar(
        const SnackBar(
          content: Text(
            'Отметьте согласие с Политикой конфиденциальности и Пользовательским соглашением',
          ),
        ),
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
      final trimmedEmail = _email.text.trim();
      await ref.read(authActionsProvider).parentSignUp(
            phone: _phone.text.trim(),
            password: _password.text,
            displayName: _displayNameForSubmit(),
            recoveryEmail: trimmedEmail,
            email: trimmedEmail,
          );
      final picked = _avatarPickedFile;
      if (picked != null && mounted) {
        try {
          await ref
              .read(parentAccessRepositoryProvider)
              .uploadMyProfileAvatarFromXFile(picked);
          avatarVersion.value++;
        } catch (e) {
          if (!mounted) return;
          context.showKlanySnackBar(
            SnackBar(
              content: Text(
                'Аккаунт создан. Загрузка фото не удалась: $e',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      context.go('/parent');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TextSpan _linkTapSpan(String text, TapGestureRecognizer r) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: kChildBrandBlue,
        decoration: TextDecoration.underline,
      ),
      recognizer: r,
    );
  }

  @override
  Widget build(BuildContext context) {
    void onBack() => context.go('/auth/parent/sign-in');

    final topInset = math.max(
      MediaQuery.paddingOf(context).top,
      kFigmaLandingMinTopInset,
    );
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      kFigmaLandingMinBottomInset,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE6F0F8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                kFigmaAuthHeroFormPaddingH,
                0,
                kFigmaAuthHeroFormPaddingH,
                bottomInset + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FigmaAuthDoubleDeckHeader(
                    navTitle: 'Регистрация',
                    onBack: onBack,
                    embeddedInPage: true,
                    horizontalPadding: 0,
                  ),
                  Center(child: _buildAvatarChip()),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _busy ? null : _showAvatarSourcePicker,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kChildBrandBlue,
                                    textStyle: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  child: Text(
                                    _avatarPreviewBytes != null
                                        ? 'Изменить фото'
                                        : 'Выбрать фото',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              /// Имя (необязательно)
                              const Padding(
                                padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                                child: Row(
                                  children: [
                                    Text('Имя', style: kFigmaAuthFieldLabelStyle),
                                    SizedBox(width: 8),
                                    Text(
                                      '(необязательно)',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kChildInkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FigmaAuthInputShell(
                                child: TextField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  style: kFigmaAuthInputTextStyle,
                                  decoration:
                                      figmaAuthFieldDecoration('Как к вам обращаться'),
                                ),
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
                                  autofillHints: const [
                                    AutofillHints.email,
                                  ],
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
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  top: 6,
                                ),
                                child: Text(
                                  'Минимум 8 символов, без пробелов',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    color: kChildInkMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 4),
                                child: Text(
                                  r'Разрешены буквы (латиница или кириллица), цифры и символы !@#$%^&*()_+-=[]{}|;:,./?',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    color: kChildInkMuted.withValues(alpha: 0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: kFigmaAuthFieldStackGap),

                              const Padding(
                                padding: EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                                child: Text(
                                  'Подтверждение пароля',
                                  style: kFigmaAuthFieldLabelStyle,
                                ),
                              ),
                              FigmaAuthInputShell(
                                child: TextField(
                                  controller: _passwordConfirm,
                                  obscureText: _obscureConfirm,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
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
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: kFigmaAuthFieldStackGap),

                              FigmaAuthPolicyRow(
                                checked: _agreePrivacy,
                                enabled: !_busy,
                                onChanged: (v) => setState(() => _agreePrivacy = v),
                                labelSpans: [
                                  const TextSpan(text: 'Я принимаю '),
                                  _linkTapSpan(
                                    'Политику конфиденциальности',
                                    _privacyReco!,
                                  ),
                                ],
                              ),
                              FigmaAuthPolicyRow(
                                checked: _agreeTerms,
                                enabled: !_busy,
                                onChanged: (v) => setState(() => _agreeTerms = v),
                                labelSpans: [
                                  const TextSpan(text: 'Я принимаю '),
                                  _linkTapSpan(
                                    'Пользовательское соглашение',
                                    _termsReco!,
                                  ),
                                ],
                              ),

                              SizedBox(height: kFigmaAuthBeforePrimaryCtaGap),
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
                                  label: 'Создать аккаунт',
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
