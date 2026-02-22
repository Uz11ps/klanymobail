import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../child_session.dart';
import '../device_identity.dart';

class ChildWaitApprovalPage extends ConsumerStatefulWidget {
  const ChildWaitApprovalPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ChildWaitApprovalPage> createState() => _ChildWaitApprovalPageState();
}

class _ChildWaitApprovalPageState extends ConsumerState<ChildWaitApprovalPage> {
  Timer? _timer;
  String _statusText = 'Запрос отправлен папе. Дождись подтверждения.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (widget.requestId.isEmpty) {
      setState(() {
        _statusText = 'Некорректная заявка. Отправь новый запрос.';
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final device = await DeviceIdentityStore.getOrCreate();
      final result = await ref.read(passwordlessChildRepositoryProvider).pollAccessRequest(
            requestId: widget.requestId,
            device: device,
          );
      if (!mounted || result == null) return;

      if (result.status == 'pending') {
        setState(() {
          _statusText = 'Запрос отправлен папе. Дождись подтверждения.';
        });
        return;
      }

      if (result.status == 'rejected') {
        _timer?.cancel();
        setState(() {
          _statusText = 'Запрос отклонен. Проверь данные и отправь снова.';
        });
        return;
      }

      if (result.status == 'approved' &&
          (result.childId ?? '').isNotEmpty &&
          (result.familyId ?? '').isNotEmpty &&
          (result.accessToken ?? '').isNotEmpty) {
        _timer?.cancel();
        await ref.read(childSessionProvider.notifier).activateFromApproval(
              childId: result.childId!,
              familyId: result.familyId!,
              childDisplayName: result.childDisplayName ?? '',
              accessToken: result.accessToken!,
            );
        if (!mounted) return;
        context.go('/child');
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ожидание подтверждения')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(_statusText, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/auth/child/request'),
                child: const Text('Отправить новую заявку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

