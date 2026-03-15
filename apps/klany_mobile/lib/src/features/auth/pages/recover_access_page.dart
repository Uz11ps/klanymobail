import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление доступа')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
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
                    messenger.showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Отправить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
