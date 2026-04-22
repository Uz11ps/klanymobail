import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';
import '../child_pin_store.dart';
import '../child_session.dart';
import '../device_identity.dart';

class ChildSignInPage extends ConsumerStatefulWidget {
  const ChildSignInPage({super.key});

  @override
  ConsumerState<ChildSignInPage> createState() => _ChildSignInPageState();
}

class _ChildSignInPageState extends ConsumerState<ChildSignInPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _authCode = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _authCode.dispose();
    super.dispose();
  }

  Future<bool> _promptPinAndVerify() async {
    if (!mounted) return false;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Введите PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'PIN (6 цифр)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final entered = controller.text.trim();
    return ChildPinStore.verify(entered);
  }

  Future<void> _quickSignIn({required bool requirePin}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final restored = await ref
          .read(passwordlessChildRepositoryProvider)
          .restoreSession(device);
      if (!mounted) return;
      if (restored == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сессия на этом устройстве не найдена. '
              'Нажмите «Зарегистрироваться».',
            ),
          ),
        );
        return;
      }
      if (requirePin) {
        final pinOk = await _promptPinAndVerify();
        if (!mounted) return;
        if (!pinOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неверный PIN-код')),
          );
          return;
        }
      }

      await ref.read(childSessionProvider.notifier).activateFromApproval(
            childId: restored.childId,
            familyId: restored.familyId,
            childDisplayName: restored.childDisplayName,
            accessToken: restored.accessToken,
          );
      if (!mounted) return;
      context.go('/child');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось войти: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordSignIn() async {
    if (_busy) return;
    final login = _login.text.trim();
    final password = _password.text.trim();
    if (login.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите телефон/мейл и пароль')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final result = await ref
          .read(passwordlessChildRepositoryProvider)
          .signInWithPassword(
            login: login,
            password: password,
            device: device,
          );
      if (!mounted) return;
      await ref.read(childSessionProvider.notifier).activateFromApproval(
            childId: result.childId,
            familyId: result.familyId,
            childDisplayName: result.childDisplayName,
            accessToken: result.accessToken,
          );
      if (!mounted) return;
      context.go('/child');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось войти: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pinSignIn() async {
    if (_busy) return;
    final hasPin = await ChildPinStore.hasPin();
    if (!hasPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN не установлен. Войдите по паролю или устройству.'),
        ),
      );
      return;
    }
    await _quickSignIn(requirePin: true);
  }

  Future<void> _codeSignIn() async {
    if (_busy) return;
    final authCode = _authCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(authCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите 6-значный код ребёнка')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final result = await ref
          .read(passwordlessChildRepositoryProvider)
          .signInWithAuthCode(
            authCode: authCode,
            device: device,
          );
      if (!mounted) return;
      await ref.read(childSessionProvider.notifier).activateFromApproval(
            childId: result.childId,
            familyId: result.familyId,
            childDisplayName: result.childDisplayName,
            accessToken: result.accessToken,
          );
      if (!mounted) return;
      context.go('/child');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось войти: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Вход ребёнка',
      subtitle:
          'Доступны: код ребёнка, телефон/мейл + пароль, PIN-код, либо вход по айди устройства.',
      children: [
        ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'По коду ребёнка',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _authCode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: clanInputDecoration(
                  label: 'Код ребёнка (6 цифр)',
                  icon: Icons.confirmation_number,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              ClanPrimaryButton(
                label: 'Вход по коду ребёнка',
                icon: Icons.vpn_key,
                busy: _busy,
                onPressed: _busy ? null : _codeSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'По телефону/мейлу и паролю',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _login,
                keyboardType: TextInputType.emailAddress,
                decoration: clanInputDecoration(
                  label: 'Телефон или мейл',
                  icon: Icons.person,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: clanInputDecoration(
                  label: 'Пароль',
                  icon: Icons.lock,
                ),
              ),
              const SizedBox(height: 12),
              ClanPrimaryButton(
                label: 'Вход по паролю',
                icon: Icons.login,
                busy: _busy,
                onPressed: _busy ? null : _passwordSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Быстрый вход на этом устройстве',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
              const SizedBox(height: 10),
              ClanPrimaryButton(
                label: _busy ? 'Входим...' : 'Вход по айди устройства',
                icon: Icons.smartphone,
                busy: _busy,
                onPressed: _busy ? null : () => _quickSignIn(requirePin: false),
              ),
              const SizedBox(height: 10),
              ClanSecondaryButton(
                label: 'Вход по PIN-коду',
                icon: Icons.pin,
                onPressed: _busy ? null : _pinSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClanSecondaryButton(
          label: 'Зарегистрироваться',
          icon: Icons.person_add,
          onPressed: _busy ? null : () => context.go('/auth/child/request'),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed:
                _busy ? null : () => context.go('/auth/sign-in/role'),
            child: const Text(
              'Назад к выбору роли',
              style: TextStyle(
                color: kChildBrandBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
