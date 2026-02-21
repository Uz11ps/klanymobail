import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../notifications_repository.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));
        return FutureBuilder<List<InAppNotificationItem>>(
          future: ref
              .read(notificationsRepositoryProvider)
              .listFamilyNotifications(family.familyId),
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <InAppNotificationItem>[];
            return CustomScrollView(
              slivers: [
                const SliverAppBar(pinned: true, title: Text('Уведомления')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: list
                          .map(
                            (n) => Card(
                              child: ListTile(
                                title: Text(n.type),
                                subtitle: Text(
                                  '${n.payload} • ${DateFormat('dd.MM HH:mm').format(n.createdAt.toLocal())}',
                                ),
                                trailing: n.status == 'read'
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(notificationsRepositoryProvider)
                                              .markRead(n.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Отмечено как прочитанное')),
                                            );
                                          }
                                        },
                                        child: const Text('Прочитано'),
                                      ),
                              ),
                            ),
                          )
                          .toList(),
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

