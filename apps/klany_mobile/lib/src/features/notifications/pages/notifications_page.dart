import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
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
        if (family == null) {
          return const Center(child: Text('Семья не найдена'));
        }
        return FutureBuilder<List<InAppNotificationItem>>(
          future: _future ??
              ref
                  .read(notificationsRepositoryProvider)
                  .listFamilyNotifications(family.familyId),
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <InAppNotificationItem>[];
            final requests = <InAppNotificationItem>[];
            final events = <InAppNotificationItem>[];
            final updates = <InAppNotificationItem>[];
            for (final n in list) {
              if (n.type == 'access_request') {
                requests.add(n);
              } else if (n.type.startsWith('quest_') ||
                  n.type.startsWith('shop_') ||
                  n.type == 'wallet_adjusted') {
                events.add(n);
              } else {
                updates.add(n);
              }
            }
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: kChildInk),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                centerTitle: true,
                title: const Text(
                  'Уведомления',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kChildInk,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _reload(family.familyId),
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.refresh,
                            color: kChildInk,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // ── "Лента семьи" header card ─────────────────────────
                  ChildSoftCard(
                    color: kChildSurfaceWhite,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Лента семьи',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kChildInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Здесь собраны покупки, задачи и важные изменения по семье.',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: kChildInkMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: kChildOutline,
                              width: 1.4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Всего событий: ${list.length}',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (list.isEmpty &&
                      snapshot.connectionState != ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Уведомлений пока нет',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            color: kChildInkMuted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  if (requests.isNotEmpty) ...[
                    const _GroupTitle('Запросы'),
                    ...requests.map(
                      (n) => _NotificationCard(
                        item: n,
                        bg: kBrandMint,
                        title: 'Новый запрос ребёнка',
                        subtitle: () {
                          final name = (n.payload['displayName'] ??
                                  n.payload['childName'] ??
                                  '')
                              .toString();
                          return name.isEmpty
                              ? 'Ребёнок запросил доступ к семье.'
                              : '$name запросил(а) доступ к семье.';
                        }(),
                        icon: Icons.child_care_outlined,
                        onMarkRead: () async {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(n.id);
                          if (!mounted) return;
                          _reload(family.familyId);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (events.isNotEmpty) ...[
                    const _GroupTitle('События'),
                    ...events.map(
                      (n) => _NotificationCard(
                        item: n,
                        bg: kBrandSunny,
                        title: 'Новое событие',
                        subtitle: _eventSubtitle(n),
                        icon: Icons.notifications_none_rounded,
                        onMarkRead: () async {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(n.id);
                          if (!mounted) return;
                          _reload(family.familyId);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (updates.isNotEmpty) ...[
                    const _GroupTitle('Обновления'),
                    ...updates.map(
                      (n) => _NotificationCard(
                        item: n,
                        bg: kBrandSky,
                        title: 'Обновление данных',
                        subtitle: 'Данные семьи были обновлены. Проверьте изменения.',
                        icon: Icons.refresh,
                        onMarkRead: () async {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(n.id);
                          if (!mounted) return;
                          _reload(family.familyId);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _eventSubtitle(InAppNotificationItem n) {
    final name = (n.payload['displayName'] ?? n.payload['childName'] ?? '')
        .toString();
    switch (n.type) {
      case 'shop_purchase_requested':
        return name.isEmpty
            ? 'Ребёнок запросил покупку в магазине.'
            : '$name запросил(а) покупку в магазине.';
      case 'shop_purchase_approved':
        return 'Покупка одобрена.';
      case 'shop_purchase_rejected':
        return 'Покупка отклонена.';
      case 'quest_submitted':
        return name.isEmpty
            ? 'Задание отправлено на проверку.'
            : '$name отправил(а) задание на проверку.';
      case 'quest_approved':
        return 'Задание принято.';
      case 'quest_rejected':
        return 'Задание отклонено.';
      case 'wallet_adjusted':
        return 'Баланс изменён.';
      default:
        return 'В семье добавлена новая задача или покупка.';
    }
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: kChildInk,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onMarkRead,
  });
  final InAppNotificationItem item;
  final Color bg;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ChildSoftCard(
        color: bg,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: kChildInk, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: kChildInk,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kChildInk,
                      elevation: 4,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Открыть',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onMarkRead,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kChildInk,
                      elevation: 4,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Прочитать',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
