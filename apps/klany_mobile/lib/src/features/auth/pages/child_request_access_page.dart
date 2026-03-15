import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../child_session.dart';
import '../device_identity.dart';

enum _AccessLookupType { familyId, parentEmail, parentPhone }

class ChildRequestAccessPage extends ConsumerStatefulWidget {
  const ChildRequestAccessPage({super.key});

  @override
  ConsumerState<ChildRequestAccessPage> createState() =>
      _ChildRequestAccessPageState();
}

class _ChildRequestAccessPageState
    extends ConsumerState<ChildRequestAccessPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _password = TextEditingController();
  final _familyCode = TextEditingController();
  final _parentContact = TextEditingController();
  final _deviceId = TextEditingController();
  bool _registered = false;
  _AccessLookupType _lookupType = _AccessLookupType.familyId;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _firstName.dispose();
    _password.dispose();
    _familyCode.dispose();
    _parentContact.dispose();
    _deviceId.dispose();
    super.dispose();
  }

  void _goToAccessStep() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _registered = true);
  }

  Future<void> _submitAccessRequest() async {
    String? familyCode;
    String? parentContact;
    if (_lookupType == _AccessLookupType.familyId) {
      final value = _familyCode.text.trim().toUpperCase();
      if (value.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите корректный Family ID')),
        );
        return;
      }
      familyCode = value;
    } else if (_lookupType == _AccessLookupType.parentEmail) {
      final value = _parentContact.text.trim().toLowerCase();
      if (!value.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите корректную почту родителя')),
        );
        return;
      }
      parentContact = value;
    } else {
      final value = _parentContact.text.trim();
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите корректный телефон родителя')),
        );
        return;
      }
      parentContact = value;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!Env.hasApiConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните .env (API_BASE_URL) чтобы отправить заявку'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final requestId = await ref
          .read(passwordlessChildRepositoryProvider)
          .submitAccessRequest(
            phone: _phone.text,
            email: _email.text,
            childFirstName: _firstName.text,
            password: _password.text.trim(),
            familyCode: familyCode,
            parentContact: parentContact,
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
    if (_deviceId.text.isEmpty) {
      DeviceIdentityStore.getOrCreate().then((device) {
        if (!mounted || _deviceId.text.isNotEmpty) return;
        setState(() => _deviceId.text = device.deviceId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_registered ? 'Ребёнок: запрос доступа' : 'Ребёнок: регистрация'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _registered
                          ? 'Шаг 2/2. Найдите семью по ID семьи, почте или телефону родителя.'
                          : 'Шаг 1/2. Зарегистрируйте ребёнка по полям:\n'
                              'телефон, мейл, имя, пароль, айди устройства.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_registered) ...[
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        return digits.length < 10 ? 'Введите корректный телефон' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Мейл',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return value.contains('@') ? null : 'Введите корректный мейл';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        prefixIcon: Icon(Icons.child_care),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return value.length < 6 ? 'Минимум 6 символов' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deviceId,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Айди устройства',
                        prefixIcon: Icon(Icons.smartphone),
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<_AccessLookupType>(
                      value: _lookupType,
                      decoration: const InputDecoration(
                        labelText: 'Способ поиска семьи',
                        prefixIcon: Icon(Icons.search),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _AccessLookupType.familyId,
                          child: Text('ID семьи'),
                        ),
                        DropdownMenuItem(
                          value: _AccessLookupType.parentEmail,
                          child: Text('Почта родителя'),
                        ),
                        DropdownMenuItem(
                          value: _AccessLookupType.parentPhone,
                          child: Text('Телефон родителя'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _lookupType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lookupType == _AccessLookupType.familyId
                          ? _familyCode
                          : _parentContact,
                      keyboardType: _lookupType == _AccessLookupType.parentPhone
                          ? TextInputType.phone
                          : TextInputType.text,
                      textCapitalization: _lookupType == _AccessLookupType.familyId
                          ? TextCapitalization.characters
                          : TextCapitalization.none,
                      decoration: InputDecoration(
                        labelText: _lookupType == _AccessLookupType.familyId
                            ? 'Family ID'
                            : _lookupType == _AccessLookupType.parentEmail
                                ? 'Почта родителя'
                                : 'Телефон родителя',
                        prefixIcon: Icon(
                          _lookupType == _AccessLookupType.familyId
                              ? Icons.groups_2
                              : _lookupType == _AccessLookupType.parentEmail
                                  ? Icons.alternate_email
                                  : Icons.phone,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : (_registered ? _submitAccessRequest : _goToAccessStep),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registered ? 'Запросить доступ' : 'Зарегистрироваться'),
                    ),
                  ),
                  if (_registered) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _registered = false),
                      child: const Text('Изменить данные регистрации'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
