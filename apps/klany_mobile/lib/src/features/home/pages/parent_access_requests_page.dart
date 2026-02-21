import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/parent_access_repository.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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

class _PendingRequestsBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ChildAccessRequestItem>>(
      future: ref.read(parentAccessRepositoryProvider).getPendingRequests(family.familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ChildAccessRequestItem>[];

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Запросы на вход'),
              actions: [
                IconButton(
                  tooltip: 'Пригласить участника',
                  onPressed: onInviteShare,
                  icon: const Icon(Icons.share),
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
                        subtitle: Text(family.familyCode),
                        trailing: TextButton(
                          onPressed: onInviteShare,
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
                                        onPressed: busy ? null : () => onReject(item.id),
                                        child: const Text('Отклонить'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: busy ? null : () => onApprove(item.id),
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

