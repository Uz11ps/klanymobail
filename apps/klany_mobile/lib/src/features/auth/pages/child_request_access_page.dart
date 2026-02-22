import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../child_session.dart';
import '../device_identity.dart';

class ChildRequestAccessPage extends ConsumerStatefulWidget {
  const ChildRequestAccessPage({super.key});

  @override
  ConsumerState<ChildRequestAccessPage> createState() => _ChildRequestAccessPageState();
}

class _ChildRequestAccessPageState extends ConsumerState<ChildRequestAccessPage> {
  final _formKey = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _familyCode = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _familyCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните .env (API_BASE_URL) чтобы отправить заявку')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final requestId = await ref.read(passwordlessChildRepositoryProvider).submitAccessRequest(
            familyCode: _familyCode.text,
            childFirstName: _firstName.text,
            childLastName: _lastName.text,
            device: device,
          );
      if (!mounted) return;
      context.go('/auth/child/wait?requestId=$requestId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить заявку: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ребёнок: запрос доступа')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Фамилия',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Введите фамилию' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _familyCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Family ID',
                      hintText: 'Например: HOMY-2026',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Введите Family ID' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Запросить доступ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

