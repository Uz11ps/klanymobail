import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../../../core/app_snackbar.dart';

class RecoverAccessPage extends ConsumerStatefulWidget {
  const RecoverAccessPage({super.key});

  @override
  ConsumerState<RecoverAccessPage> createState() => _RecoverAccessPageState();
}

class _RecoverAccessPageState extends ConsumerState<RecoverAccessPage> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (email.isEmpty && phone.isEmpty) return;
    if (!Env.hasApiConfig) {
      context.showKlanySnackBar(const SnackBar(content: Text('API не настроен')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (email.isNotEmpty) {
        await ref.read(authActionsProvider).requestPasswordReset(email: email);
        if (!mounted) return;
        context.showKlanySnackBar(
          const SnackBar(
            content: Text('Если email зарегистрирован — придёт письмо со ссылкой'),
          ),
        );
        return;
      }
      await ref.read(authActionsProvider).requestRecovery(phone: phone);
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Запрос на восстановление отправлен в Telegram')),
      );
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = kChildInk; // #1E2D52 dark navy
    const fieldColor = Color(0xFFFFFFFF);
    const labelColor = Color(0xFFB0BDD6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Восстановление доступа',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email field
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: labelColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: fieldColor,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.7)),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF3A4F72)),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF3A4F72)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kChildBrandBlue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Phone field
              Row(
                children: [
                  const Icon(Icons.phone_outlined, color: labelColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: fieldColor,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Телефон (резерв для восстановления)',
                        hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.7)),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF3A4F72)),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF3A4F72)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kChildBrandBlue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6FD0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF4A4580),
                    textStyle: kKlanyBrandBluePillTextStyle,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Отправить'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final email = _email.text.trim();
                    if (email.contains('@')) {
                      context.push(
                        '/auth/forgot-password/code?email=${Uri.encodeComponent(email)}',
                      );
                    } else {
                      context.push('/auth/forgot-password');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A4F72), width: 1.4),
                    textStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  child: const Text(
                    'Уже есть код из письма',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
