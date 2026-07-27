import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/parent_access_repository.dart';
import '../child_soft_ui.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/klany_live_poll.dart';

class ParentAccessRequestsPage extends ConsumerStatefulWidget {
  const ParentAccessRequestsPage({super.key});

  @override
  ConsumerState<ParentAccessRequestsPage> createState() => _ParentAccessRequestsPageState();
}

class _ParentAccessRequestsPageState extends ConsumerState<ParentAccessRequestsPage> {
  bool _busy = false;

  Future<void> _shareInvite(ParentFamilyContext contextData) async {
    final clanName = (contextData.clanName ?? '').trim().isEmpty
        ? 'вашей семьи'
        : contextData.clanName!.trim();
    final text = 'Присоединяйся к Клану $clanName. '
        'Введи в приложении Family ID: ${contextData.familyCode}';
    await SharePlus.instance.share(
      ShareParams(text: text),
    );
  }

  Future<void> _approve(String requestId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).approveRequest(requestId);
      ref.invalidate(parentFamilyContextProvider);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка подтверждения: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String requestId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).rejectRequest(requestId);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка отклонения: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) {
          return const Center(child: Text('Семья не найдена'));
        }

        return _PendingRequestsBody(
          family: family,
          busy: _busy,
          onApprove: _approve,
          onReject: _reject,
          onInviteShare: () => _shareInvite(family),
        );
      },
    );
  }
}

class _PendingRequestsBody extends ConsumerStatefulWidget {
  const _PendingRequestsBody({
    required this.family,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onInviteShare,
  });

  final ParentFamilyContext family;
  final bool busy;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final VoidCallback onInviteShare;

  @override
  ConsumerState<_PendingRequestsBody> createState() =>
      _PendingRequestsBodyState();
}

class _PendingRequestsBodyState extends ConsumerState<_PendingRequestsBody>
    with KlanyLivePollConsumerMixin {
  Future<List<ChildAccessRequestItem>>? _requestsFuture;

  @override
  void onKlanyLivePoll({bool silent = true}) {
    _reloadRequests();
  }

  void _reloadRequests() {
    final fut = ref
        .read(parentAccessRepositoryProvider)
        .getPendingRequests(widget.family.familyId);
    setState(() {
      _requestsFuture = fut;
    });
  }

  @override
  void initState() {
    super.initState();
    final fut = ref
        .read(parentAccessRepositoryProvider)
        .getPendingRequests(widget.family.familyId);
    _requestsFuture = fut;
  }

  @override
  void didUpdateWidget(covariant _PendingRequestsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.family.familyId != widget.family.familyId) {
      final fut = ref
          .read(parentAccessRepositoryProvider)
          .getPendingRequests(widget.family.familyId);
      setState(() {
        _requestsFuture = fut;
      });
      return;
    }
    if (oldWidget.busy && !widget.busy) {
      _reloadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildAccessRequestItem>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ChildAccessRequestItem>[];

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              foregroundColor: kChildInk,
              title: const Text(
                'Запросы на вход',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Пригласить участника',
                  onPressed: widget.onInviteShare,
                  icon: const Icon(Icons.share, color: kChildInk),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.family_restroom),
                        title: const Text('Family ID'),
                        subtitle: Text(widget.family.familyCode),
                        trailing: TextButton(
                          onPressed: widget.onInviteShare,
                          child: const Text('Поделиться'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (list.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Новых заявок пока нет'),
                        ),
                      )
                    else
                      ...list.map(
                        (item) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.childLastName} ${item.childFirstName}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text('ID устройства: ${item.deviceId}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Запрос: ${DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt.toLocal())}',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: widget.busy
                                            ? null
                                            : () =>
                                                widget.onReject(item.id),
                                        child: const Text('Отклонить'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: widget.busy
                                            ? null
                                            : () =>
                                                widget.onApprove(item.id),
                                        child: const Text('Подтвердить'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

