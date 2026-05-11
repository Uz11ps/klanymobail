import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';

InputDecoration _authInput(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kChildInkMuted, fontSize: 15),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
    ),
    suffixIcon: suffixIcon,
  );
}

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните имя и телефон')),
      );
      return;
    }
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль минимум 6 символов')),
      );
      return;
    }
    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCloud,
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            const Center(
              child: Text(
                'CLAN CAPITAL',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: kChildBrandBlue,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _authInput('Имя участника'),
              style: const TextStyle(fontSize: 15, color: kChildInk),
            ),
            const SizedBox(height: 16),
            // Avatar picker
            const Text(
              'Выбор аватара',
              style: TextStyle(
                fontSize: 13,
                color: kChildInkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ..._avatars.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = a),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kChildSurfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedAvatar == a
                              ? kChildBrandBlue
                              : kChildOutline,
                          width: _selectedAvatar == a ? 2.2 : 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(a, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                )),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _avatars.map((a) => GestureDetector(
                              onTap: () {
                                setState(() => _selectedAvatar = a);
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: kChildSurfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _selectedAvatar == a
                                        ? kChildBrandBlue
                                        : kChildOutline,
                                    width: _selectedAvatar == a ? 2.2 : 1.4,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(a, style: const TextStyle(fontSize: 30)),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: kChildSurfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kChildOutline, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, color: kChildInkMuted, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _authInput('Телефон'),
              style: const TextStyle(fontSize: 15, color: kChildInk),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _authInput('Email (для веб-админки)'),
              style: const TextStyle(fontSize: 15, color: kChildInk),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: _authInput(
                'Пароль',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: kChildInkMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              style: const TextStyle(fontSize: 15, color: kChildInk),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kBrandMint,
                  foregroundColor: const Color(0xFF000000),
                  minimumSize: const Size.fromHeight(56),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1F4F1B),
                        ),
                      )
                    : const Text(
                        'ПРИНЯТЬ В КЛАН',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/auth/parent/sign-in'),
                style: TextButton.styleFrom(foregroundColor: kChildBrandBlue),
                child: const Text(
                  'Все участники (0)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
