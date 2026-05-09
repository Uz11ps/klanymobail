import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';
import '../child_session.dart';
import '../device_identity.dart';

// Re-use the _SmyshlCard from parent_sign_in via copy (can't import private class).
class _SmyshlCard extends StatelessWidget {
  const _SmyshlCard({
    required this.number,
    required this.emoji1,
    required this.emoji2,
    required this.title,
    required this.description,
  });

  final int number;
  final String emoji1;
  final String emoji2;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      color: kChildSurfaceWhite,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kChildAccentOrange,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 7),
              Text(
                'СМЫСЛ $number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3ECF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text('$emoji1$emoji2', style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kChildBrandBlue,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kChildInkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

// ─── Child sign-in page ──────────────────────────────────────────────────────

class ChildSignInPage extends ConsumerStatefulWidget {
  const ChildSignInPage({super.key});

  @override
  ConsumerState<ChildSignInPage> createState() => _ChildSignInPageState();
}

class _ChildSignInPageState extends ConsumerState<ChildSignInPage> {
  final _authCode = TextEditingController();
  bool _busy = false;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось войти: $e')));
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
            // CLAN CAPITAL header
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
            // СМЫСЛ 3 card
            const _SmyshlCard(
              number: 3,
              emoji1: '👥',
              emoji2: '🛡️',
              title: 'ТВОЯ КОМАНДА',
              description:
                  'Добавь детей, чтобы распределять задачи и отслеживать их финансовый рост в реальном времени',
            ),
            const SizedBox(height: 24),
            // Code entry
            TextField(
              controller: _authCode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _authInput('Код участника').copyWith(counterText: ''),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kChildInk,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _codeSignIn,
                style: FilledButton.styleFrom(
                  backgroundColor: kBrandMint,
                  foregroundColor: const Color(0xFF1F4F1B),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'ВОЙТИ В КЛАН',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Попросите Главу Клана поделиться кодом активации',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: kChildInkMuted.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
