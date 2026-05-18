import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';
import '../child_session.dart';
import '../device_identity.dart';
import '../../../core/app_snackbar.dart';

class JoinFamilyCodePage extends ConsumerStatefulWidget {
  const JoinFamilyCodePage({super.key, required this.role});

  final String role;

  @override
  ConsumerState<JoinFamilyCodePage> createState() => _JoinFamilyCodePageState();
}

class _JoinFamilyCodePageState extends ConsumerState<JoinFamilyCodePage> {
  final _code = TextEditingController();
  bool _busy = false;

  bool get _isParent => widget.role == 'parent';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите 6-значный код')),
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
      if (_isParent) {
        await ref.read(authActionsProvider).parentSignInByCode(code: code);
        if (!mounted) return;
        context.go('/parent');
        return;
      }

      final device = await DeviceIdentityStore.getOrCreate();
      final result = await ref
          .read(passwordlessChildRepositoryProvider)
          .signInWithAuthCode(authCode: code, device: device);
      if (!mounted) return;
      await ref.read(childSessionProvider.notifier).activateFromApproval(
            childId: result.childId,
            familyId: result.familyId,
            childDisplayName: result.childDisplayName,
            accessToken: result.accessToken,
            avatarObjectKey: result.avatarObjectKey,
          );
      if (!mounted) return;
      context.go('/child');
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Не удалось войти: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isParent
        ? 'Присоединиться как родитель'
        : 'Присоединиться как ребёнок';

    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: title,
      subtitle:
          'Введите персональный 6-значный код, который создал Глава Клана в настройках семьи.',
      children: [
        ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: clanInputDecoration(
                  label: 'Код доступа (6 цифр)',
                  icon: Icons.vpn_key,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              ClanPrimaryButton(
                label: _busy ? 'Вход...' : 'Присоединиться',
                icon: Icons.login,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
              if (_isParent) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.go('/auth/parent/sign-up'),
                    child: const Text(
                      'Я Глава Клана — зарегистрироваться',
                      style: TextStyle(
                        color: kChildBrandBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

