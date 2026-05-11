import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';
import '../child_session.dart';
import '../device_identity.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
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
      await ref.read(childSessionProvider.notifier).activateFromApproval(
            childId: result.childId,
            familyId: result.familyId,
            childDisplayName: result.childDisplayName,
            accessToken: result.accessToken,
          );
      if (mounted) context.go('/child');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCloud,
      appBar: AppBar(
        backgroundColor: kBgCloud,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kChildInk),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/auth/landing'),
        ),
        centerTitle: true,
        title: const Text(
          'Регистрация',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            // Hero card with flag image (text and bg are part of the image)
            AspectRatio(
              aspectRatio: 1.05,
              child: Image.asset(
                'assets/figma/hero_flag.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(color: kBrandSky),
              ),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 10),
              child: Text(
                'Ввод ключа',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
            ),
            // Soft input with shadow
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E2D52).withValues(alpha: 0.10),
                    offset: const Offset(0, 6),
                    blurRadius: 18,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: TextField(
                controller: _authCode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: _obscure,
                decoration: _authInput(
                  '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: kChildInkMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ).copyWith(counterText: ''),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            SoftButton(
              label: _busy ? '...' : 'Войти',
              bg: kBrandMint,
              fg: const Color(0xFF1F4F1B),
              fontSize: 17,
              onTap: _busy ? null : _codeSignIn,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: kChildBrandBlue),
                child: const Text(
                  'Забыли ключ?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
