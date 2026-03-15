import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../notifications_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  Future<List<InAppNotificationItem>>? _future;

  void _reload(String familyId) {
    setState(() {
      _future = ref
          .read(notificationsRepositoryProvider)
          .listFamilyNotifications(familyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null)
          return const Center(child: Text('Семья не найдена'));
        return FutureBuilder<List<InAppNotificationItem>>(
          future:
              _future ??
              ref
                  .read(notificationsRepositoryProvider)
                  .listFamilyNotifications(family.familyId),
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <InAppNotificationItem>[];
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('Уведомления'),
                  actions: [
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: () => _reload(family.familyId),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Очистить',
                      onPressed: list.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(notificationsRepositoryProvider)
                                  .clearAll();
                              if (!mounted) return;
                              _reload(family.familyId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Уведомления очищены'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.delete_sweep),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (snapshot.hasError)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Ошибка: ${snapshot.error}'),
                            ),
                          )
                        else if (list.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Уведомлений пока нет'),
                            ),
                          )
                        else
                          ...list.map(
                            (n) => Card(
                              child: ListTile(
                                title: Text(n.type),
                                subtitle: Text(
                                  '${n.payload} • ${DateFormat('dd.MM HH:mm').format(n.createdAt.toLocal())}',
                                ),
                                trailing: n.status == 'read'
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      )
                                    : TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                notificationsRepositoryProvider,
                                              )
                                              .markRead(n.id);
                                          if (!mounted) return;
                                          _reload(family.familyId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Отмечено как прочитанное',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Прочитано'),
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
      },
    );
  }
}
