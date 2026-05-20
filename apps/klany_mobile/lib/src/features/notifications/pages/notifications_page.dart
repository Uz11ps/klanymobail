import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
import '../../home/pages/parent_access_requests_page.dart';
import '../../quests/pages/parent_quests_page.dart';
import '../../quests/quests_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/pages/parent_wallets_page.dart';
import '../notifications_repository.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/value_bump.dart';

bool _ruFemaleNameHint(String name) {
  final t = name.trim().toLowerCase();
  return t.endsWith('а') || t.endsWith('я');
}

const Color _figmaWhite = Color(0xFFFFFFFF);
const Color _figmaMint = Color(0xFFD9F6C2);
const Color _figmaSunny = Color(0xFFF9E8A5);
const Color _figmaSky = Color(0xFFC1D8F5);

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsHubSnapshot {
  _NotificationsHubSnapshot({
    required this.notifications,
    required this.reverseQuests,
    required this.childNamesById,
  });

  final List<InAppNotificationItem> notifications;
  final List<ParentQuestItem> reverseQuests;
  final Map<String, String> childNamesById;
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
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
        return _NotificationsHubScreen(familyId: family.familyId);
      },
    );
  }
}

/// Каркас: фон + `Scaffold` не пересобираются при обновлении ленты, только слой ниже.
class _NotificationsHubScreen extends StatelessWidget {
  const _NotificationsHubScreen({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: FigmaAuthScreenBackground()),
          Positioned.fill(
            child: _NotificationsInteractiveContent(familyId: familyId),
          ),
        ],
      ),
    );
  }
}

/// Лента и секции карточек — живой `State` + тихий опрос API.
class _NotificationsInteractiveContent extends ConsumerStatefulWidget {
  const _NotificationsInteractiveContent({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_NotificationsInteractiveContent> createState() =>
      _NotificationsInteractiveContentState();
}

class _NotificationsInteractiveContentState
    extends ConsumerState<_NotificationsInteractiveContent> {
  _NotificationsHubSnapshot? _hub;
  bool _initialLoading = true;
  Object? _loadError;
  bool _refreshInProgress = false;
  Timer? _livePoll;

  Future<_NotificationsHubSnapshot> _fetchHub(String familyId) async {
    final notifications = await ref
        .read(notificationsRepositoryProvider)
        .listFamilyNotifications(familyId);
    final questRepo = ref.read(questsRepositoryProvider);
    final quests = await questRepo.getParentQuests(familyId);
    final children = await questRepo.getFamilyChildren(familyId);
    final names = <String, String>{
      for (final c in children) c.id: c.displayName,
    };
    final reverse = quests
        .where((q) => q.distributionType == 'reverse')
        .toList();
    return _NotificationsHubSnapshot(
      notifications: notifications,
      reverseQuests: reverse,
      childNamesById: names,
    );
  }

  Future<void> _bootstrap() async {
    try {
      final s = await _fetchHub(widget.familyId);
      if (!mounted) return;
      setState(() {
        _hub = s;
        _initialLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hub = null;
        _initialLoading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _refreshInProgress = true;
      _loadError = null;
    });
    try {
      final s = await _fetchHub(widget.familyId);
      if (!mounted) return;
      setState(() {
        _hub = s;
        _refreshInProgress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshInProgress = false);
      context.showKlanySnackBar(
        SnackBar(content: Text('Не удалось обновить ленту: $e')),
      );
    }
  }

  Future<void> _silentPoll() async {
    if (!mounted || _refreshInProgress) return;
    try {
      final s = await _fetchHub(widget.familyId);
      if (!mounted || _refreshInProgress) return;
      setState(() {
        _hub = s;
        _loadError = null;
      });
    } catch (_) {}
  }

  void _patchNotificationRead(String id) {
    final h = _hub;
    if (h == null) return;
    setState(() {
      _hub = _NotificationsHubSnapshot(
        notifications: [
          for (final e in h.notifications)
            if (e.id == id)
              InAppNotificationItem(
                id: e.id,
                type: e.type,
                status: 'read',
                createdAt: e.createdAt,
                payload: e.payload,
              )
            else
              e,
        ],
        reverseQuests: h.reverseQuests,
        childNamesById: h.childNamesById,
      );
    });
  }

  Future<void> _markNotificationRead(InAppNotificationItem n) async {
    if (n.status == 'read') return;
    try {
      await ref.read(notificationsRepositoryProvider).markRead(n.id);
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Не удалось отметить: $e')),
      );
      return;
    }
    if (!mounted) return;
    _patchNotificationRead(n.id);
  }

  Future<void> _openNotificationThenNavigate(InAppNotificationItem n) async {
    if (n.status != 'read') {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(n.id);
        if (mounted) _patchNotificationRead(n.id);
      } catch (_) {
        // Не блокируем переход: пользователь всё равно открыл цель.
      }
    }
    if (!mounted) return;
    _openNotificationTarget(n);
  }

  void _openNotificationTarget(InAppNotificationItem n) {
    switch (n.type) {
      case 'access_request':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const ParentAccessRequestsPage(),
          ),
        );
        return;
      case 'shop_purchase_requested':
      case 'shop_purchase_approved':
      case 'shop_purchase_rejected':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const ParentShopPage(initialTab: 2),
          ),
        );
        return;
      case 'quest_submitted':
      case 'quest_approved':
      case 'quest_rejected':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                const ParentQuestsPage(initialEconomySegment: 2),
          ),
        );
        return;
      case 'wallet_adjusted':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const ParentWalletsPage(),
          ),
        );
        return;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
    _livePoll = Timer.periodic(kParentLivePollInterval, (_) {
      Future<void>.microtask(_silentPoll);
    });
  }

  @override
  void dispose() {
    _livePoll?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NotificationsInteractiveContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      setState(() {
        _hub = null;
        _initialLoading = true;
        _loadError = null;
        _refreshInProgress = false;
      });
      Future<void>.microtask(_bootstrap);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading && _hub == null && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _hub == null) {
      return Center(child: Text('Ошибка: $_loadError'));
    }

    final hub = _hub ??
        _NotificationsHubSnapshot(
          notifications: const <InAppNotificationItem>[],
          reverseQuests: const <ParentQuestItem>[],
          childNamesById: const <String, String>{},
        );

    final listVisible = hub.notifications
        .where((n) => n.status != 'read')
        .toList();
    final reverseQuests = hub.reverseQuests;
    final totalItems = listVisible.length + reverseQuests.length;
    const bumpCap = 48;
    final feedBumpKey =
        '$totalItems|${reverseQuests.map((q) => '${q.id}:${q.status}').join(',')}|${listVisible.take(bumpCap).map((n) => '${n.id}:${n.status}').join(',')}';
    final requests = <InAppNotificationItem>[];
    final events = <InAppNotificationItem>[];
    final updates = <InAppNotificationItem>[];
    for (final n in listVisible) {
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

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = klanyResponsiveContentWidth(constraints.maxWidth);
          final sidePadding = constraints.maxWidth < 430 ? 9.0 : 19.0;
          return Center(
            child: SizedBox(
              width: pageWidth,
              child: RepaintBoundary(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    31,
                    sidePadding,
                    32,
                  ),
                  children: [
                    _NotificationsHeader(
                      onBack: () => Navigator.of(context).maybePop(),
                      onRefresh: _reload,
                    ),
                    if (_refreshInProgress) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        color: kChildBrandBlue,
                        backgroundColor: kChildOutline,
                      ),
                    ],
                    const SizedBox(height: 31),
                    _FigmaFeedCard(
                      color: _figmaWhite,
                      padding: const EdgeInsets.fromLTRB(
                        10,
                        24,
                        10,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Лента семьи',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Здесь собраны покупки, задачи и важные изменения по семье.',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: kChildInk,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(62),
                              border: Border.all(
                                color: Colors.black.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: ValueBumpWrap(
                              changeKey: feedBumpKey,
                              child: Text(
                                'Всего событий: $totalItems',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: kChildInk,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (totalItems == 0 &&
                        !_initialLoading &&
                        !_refreshInProgress)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Пока пусто: нет задач от детей к вам '
                            '(с открытым статусом) и записей ленты',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: kChildInkMuted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    if (reverseQuests.isNotEmpty) ...[
                      const _GroupTitle('К вам от ребёнка'),
                      const Padding(
                        padding: EdgeInsets.only(
                          left: 4,
                          right: 4,
                          bottom: 14,
                        ),
                        child: Text(
                          'Ваши задачи — ребёнок попросил, исполняете вы. Это '
                          'не задачи для ребёнка.',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kChildInkMuted,
                            height: 1.38,
                          ),
                        ),
                      ),
                      ...reverseQuests.map(
                        (q) => Padding(
                          key: ValueKey<String>('reverse-${q.id}'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReverseQuestParentCard(
                            quest: q,
                            childHint: () {
                              final id = q.childIds.isEmpty
                                  ? ''
                                  : q.childIds.first;
                              if (id.isEmpty) return 'ребёнка';
                              final name = hub.childNamesById[id];
                              return name == null || name.isEmpty
                                  ? 'ребёнка'
                                  : name;
                            }(),
                            onComplete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text(
                                    'Задача от ребёнка выполнена?',
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Вы отметаете выполнение той задачи, '
                                        'которую поручили вам, а не ребёнку.',
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Монеты (${q.rewardAmount}) уже списаны с '
                                        'счёта ребёнка при создании задачи. После '
                                        'подтверждения повторно не начисляются.',
                                      ),
                                      const SizedBox(height: 16),
                                      FigmaDialogActionStack(
                                        onCancel: () =>
                                            Navigator.pop(ctx, false),
                                        onConfirm: () =>
                                            Navigator.pop(ctx, true),
                                        confirmLabel:
                                            'Сделано — закрыть',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (confirm != true || !context.mounted) {
                                return;
                              }
                              try {
                                await ref
                                    .read(questsRepositoryProvider)
                                    .closeQuest(questId: q.id);
                                if (!context.mounted) return;
                                await _reload();
                                if (!context.mounted) return;
                                context.showKlanySnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Задача от ребёнка закрыта. Оплата уже была '
                                      'списана с счёта ребёнка при создании.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                context.showKlanySnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (requests.isNotEmpty) ...[
                      const _GroupTitle('Запросы'),
                      ...requests.map(
                        (n) => KeyedSubtree(
                          key: ValueKey<String>('nf-req-${n.id}'),
                          child: _NotificationCard(
                            bg: _figmaMint,
                            title: 'Новый запрос ребёнка',
                            subtitle: () {
                              final name =
                                  (n.payload['displayName'] ??
                                          n.payload['childName'] ??
                                          '')
                                      .toString();
                              return name.isEmpty
                                  ? 'Ребёнок запросил доступ к семье.'
                                  : '$name запросил(а) доступ к семье.';
                            }(),
                            icon: Icons.child_care_outlined,
                            onOpen: () {
                              unawaited(_openNotificationThenNavigate(n));
                            },
                            onMarkRead: () {
                              unawaited(_markNotificationRead(n));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (events.isNotEmpty) ...[
                      const _GroupTitle('События'),
                      ...events.map(
                        (n) => KeyedSubtree(
                          key: ValueKey<String>('nf-ev-${n.id}'),
                          child: _NotificationCard(
                            bg: _figmaSunny,
                            title: 'Новое событие',
                            subtitle: _eventSubtitle(n),
                            icon: Icons.notifications_none_rounded,
                            onOpen: () {
                              unawaited(_openNotificationThenNavigate(n));
                            },
                            onMarkRead: () {
                              unawaited(_markNotificationRead(n));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (updates.isNotEmpty) ...[
                      const _GroupTitle('Обновления'),
                      ...updates.map(
                        (n) => KeyedSubtree(
                          key: ValueKey<String>('nf-up-${n.id}'),
                          child: _NotificationCard(
                            bg: _figmaSky,
                            title: 'Обновление данных',
                            subtitle:
                                'Данные семьи были обновлены. '
                                'Проверьте изменения.',
                            icon: Icons.refresh,
                            onOpen: () {
                              unawaited(_openNotificationThenNavigate(n));
                            },
                            onMarkRead: () {
                              unawaited(_markNotificationRead(n));
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _eventSubtitle(InAppNotificationItem n) {
    final name = (n.payload['displayName'] ?? n.payload['childName'] ?? '')
        .toString();
    switch (n.type) {
      case 'shop_purchase_requested':
        final product =
            (n.payload['productTitle'] ?? n.payload['title'] ?? '')
                .toString()
                .trim();
        final nm = name.isEmpty
            ? ''
            : name.trim();
        if (nm.isEmpty) {
          return product.isEmpty
              ? 'Ребёнок запросил покупку.'
              : 'Запрошена покупка $product.';
        }
        final v = _ruFemaleNameHint(nm)
            ? 'запросила покупку'
            : 'запросил покупку';
        return product.isEmpty
            ? '$nm $v.'
            : '$nm — $v $product';
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

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: onBack,
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Уведомления',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.0,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRefresh,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.refresh, color: Colors.black, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}

class _FigmaFeedCard extends StatelessWidget {
  const _FigmaFeedCard({
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.fromLTRB(15, 20, 15, 20),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.04),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Карточка активной спеццели родителя (обратный квест).
class _ReverseQuestParentCard extends StatelessWidget {
  const _ReverseQuestParentCard({
    required this.quest,
    required this.childHint,
    required this.onComplete,
  });

  final ParentQuestItem quest;
  final String childHint;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final desc = quest.description.trim();
    final fromLine = childHint == 'ребёнка'
        ? 'Запрос от ребёнка'
        : 'Запрос от: $childHint';
    const ink = kChildInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'К ВАМ',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChildSoftCard(
          color: kBrandMint,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kChildInk.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.child_care_rounded,
                          color: ink,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Задача от ребёнка — ваше исполнение, не школьное задание малышу.',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fromLine,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: kChildInk,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quest.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Оплата с счёта ребёнка: ${quest.rewardAmount} монет',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Сделали в жизни — нажмите ниже: квест закроется. Монеты '
                'ребёнка уже списаны за эту просьбу.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: kChildInk.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Комментарий ребёнка: $desc',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: kChildInk.withValues(alpha: 0.55),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kChildInk,
                  elevation: 4,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Сделано мной — закрыть',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: kChildInk,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onOpen,
    required this.onMarkRead,
  });
  final Color bg;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _FigmaFeedCard(
        color: bg,
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: kChildInk, size: 29),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kChildInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kChildInk,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kChildInk,
                      elevation: 4,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(41),
                      ),
                    ),
                    child: const Text(
                      'Открыть',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: FilledButton(
                    onPressed: onMarkRead,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kChildInk,
                      elevation: 4,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(41),
                      ),
                    ),
                    child: const Text(
                      'Прочитать',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
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
