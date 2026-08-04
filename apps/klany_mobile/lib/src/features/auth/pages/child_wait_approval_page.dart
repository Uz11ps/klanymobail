import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_snackbar.dart';
import '../../../core/klany_error_view.dart';
import '../../home/child_soft_ui.dart';
import '../child_session.dart';
import '../device_identity.dart';

class ChildWaitApprovalPage extends ConsumerStatefulWidget {
  const ChildWaitApprovalPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ChildWaitApprovalPage> createState() =>
      _ChildWaitApprovalPageState();
}

class _ChildWaitApprovalPageState extends ConsumerState<ChildWaitApprovalPage> {
  Timer? _timer;
  String _statusText =
      'Запрос отправлен родителю. После подтверждения вход выполнится автоматически.';
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
      final result = await ref
          .read(passwordlessChildRepositoryProvider)
          .pollAccessRequest(requestId: widget.requestId, device: device);
      if (!mounted || result == null) return;

      if (result.status == 'pending') {
        setState(() {
          _statusText =
              'Ожидаем подтверждение родителя. Если родитель подтвердит позже, откройте "Вход -> Ребёнок" на этом же устройстве.';
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
        await ref
            .read(childSessionProvider.notifier)
            .activateFromApproval(
              childId: result.childId!,
              familyId: result.familyId!,
              childDisplayName: result.childDisplayName ?? '',
              accessToken: result.accessToken!,
              avatarObjectKey: result.avatarObjectKey,
            );
        if (!mounted) return;
        context.go('/child');
      }
    } catch (e) {
      if (!mounted) return;
      _timer?.cancel();
      klanyFailAndGoBack(context, error: e);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Ожидание подтверждения',
      subtitle:
          'Запрос уже у родителя. Как только он одобрит, вход выполнится автоматически.',
      children: [
        ChildSoftCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kChildBrandBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: kChildBrandBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kChildInk,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ClanPrimaryButton(
                label: 'Проверить сейчас',
                icon: Icons.refresh,
                busy: _busy,
                onPressed: _busy ? null : _poll,
              ),
              const SizedBox(height: 10),
              ClanSecondaryButton(
                label: 'Отправить новую заявку',
                icon: Icons.edit,
                onPressed: () => context.go('/auth/child/request'),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/sign-in/role'),
                  child: const Text(
                    'К выбору роли',
                    style: TextStyle(
                      color: kChildBrandBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
