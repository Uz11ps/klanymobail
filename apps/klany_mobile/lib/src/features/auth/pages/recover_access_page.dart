import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';
import '../auth_actions.dart';

class RecoverAccessPage extends ConsumerStatefulWidget {
  const RecoverAccessPage({super.key});

  @override
  ConsumerState<RecoverAccessPage> createState() => _RecoverAccessPageState();
}

class _RecoverAccessPageState extends ConsumerState<RecoverAccessPage> {
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;
    if (!Env.hasApiConfig) {
      messenger.showSnackBar(
        const SnackBar(content: Text('API не настроен')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).requestRecovery(phone: phone);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Запрос на восстановление отправлен')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Восстановление доступа',
      subtitle:
          'Введите телефон, с которого регистрировались. Мы отправим запрос в поддержку.',
      children: [
        ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: clanInputDecoration(
                  label: 'Телефон',
                  icon: Icons.phone,
                ),
              ),
              const SizedBox(height: 16),
              ClanPrimaryButton(
                label: _busy ? 'Отправляем...' : 'Отправить',
                icon: Icons.send,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
