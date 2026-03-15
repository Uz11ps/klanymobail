import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../auth/device_identity.dart';
import '../../auth/auth_actions.dart';
import '../../auth/parent_access_repository.dart';
import '../../auth/parent_session.dart';
import 'parent_family_settings_page.dart';
import 'parent_access_requests_page.dart';
import '../../quests/pages/parent_quests_page.dart';
import '../../wallet/pages/parent_wallets_page.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../notifications/fcm.dart';
import '../../wallet/wallet_repository.dart';
import '../../quests/quests_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';

class ParentHomePage extends ConsumerStatefulWidget {
  const ParentHomePage({super.key});

  @override
  ConsumerState<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends ConsumerState<ParentHomePage> {
  int _index = 0;
  int _registerAttempts = 0;
  int _pendingRequestsCount = 0;
  Timer? _pendingRequestsTimer;

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  void initState() {
    super.initState();
    _registerDevice();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    _refreshPendingRequests();
    _pendingRequestsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshPendingRequests(),
    );
  }

  Future<void> _maybeShowTour() async {
    final seen = await OnboardingStore.isParentTourSeen();
    if (seen || !mounted) return;
    await showOnboardingTourDialog(
      context: context,
      title: parentTourTitle,
      steps: parentTourSteps,
    );
    await OnboardingStore.setParentTourSeen();
  }

  @override
  void dispose() {
    _pendingRequestsTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPendingRequests() async {
    try {
      final family = await ref
          .read(parentAccessRepositoryProvider)
          .getFamilyContext();
      if (family == null) return;
      final items = await ref
          .read(parentAccessRepositoryProvider)
          .getPendingRequests(family.familyId);
      if (!mounted) return;
      final nextCount = items.length;
      if (nextCount != _pendingRequestsCount) {
        setState(() => _pendingRequestsCount = nextCount);
      }
    } catch (_) {
      // Silent refresh to avoid noisy UI.
    }
  }

  Future<void> _registerDevice() async {
    final identity = await DeviceIdentityStore.getOrCreate();
    final userId = ref.read(parentSessionProvider).asData?.value?.userId;
    if (userId == null) return;

    final platform = _platformName();
    final pushToken = await Fcm.getToken();
    // For mobile push platforms require a real FCM token; retry shortly.
    if ((platform == 'android' || platform == 'ios') &&
        (pushToken == null || pushToken.isEmpty)) {
      if (_registerAttempts < 3) {
        _registerAttempts += 1;
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) _registerDevice();
        });
      }
      return;
    }
    final tokenToSave = (pushToken != null && pushToken.isNotEmpty)
        ? pushToken
        : 'parent-${identity.deviceId}';
    await ref
        .read(notificationsRepositoryProvider)
        .registerDevice(platform: platform, pseudoPushToken: tokenToSave);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ParentDashboardPage(
        onOpenQuests: () => setState(() => _index = 1),
        onOpenShop: () => setState(() => _index = 2),
        onOpenWallet: () => setState(() => _index = 3),
        onOpenNotifications: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
          );
        },
      ),
      const ParentQuestsPage(),
      const ParentShopPage(),
      const ParentWalletsPage(),
      const ParentAccessRequestsPage(),
      const ParentFamilySettingsPage(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard),
              label: 'Главная',
            ),
            NavigationDestination(icon: Icon(Icons.task_alt), label: 'Квесты'),
            NavigationDestination(icon: Icon(Icons.store), label: 'Магазин'),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Кошелек',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _pendingRequestsCount > 0,
                label: Text('$_pendingRequestsCount'),
                child: const Icon(Icons.notifications),
              ),
              label: 'Заявки',
            ),
            NavigationDestination(icon: Icon(Icons.shield), label: 'Штаб'),
          ],
        ),
      ),
    );
  }
}

class _ParentDashboardPage extends StatelessWidget {
  const _ParentDashboardPage({
    required this.onOpenQuests,
    required this.onOpenShop,
    required this.onOpenWallet,
    required this.onOpenNotifications,
  });

  final VoidCallback onOpenQuests;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return _ParentDashboardBody(
      onOpenQuests: onOpenQuests,
      onOpenShop: onOpenShop,
      onOpenWallet: onOpenWallet,
      onOpenNotifications: onOpenNotifications,
    );
  }
}

class _ParentDashboardBody extends ConsumerStatefulWidget {
  const _ParentDashboardBody({
    required this.onOpenQuests,
    required this.onOpenShop,
    required this.onOpenWallet,
    required this.onOpenNotifications,
  });

  final VoidCallback onOpenQuests;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenNotifications;

  @override
  ConsumerState<_ParentDashboardBody> createState() =>
      _ParentDashboardBodyState();
}

class _ParentDashboardBodyState extends ConsumerState<_ParentDashboardBody> {
  bool _initialLoading = true;
  bool _refreshing = false;
  Object? _loadError;
  ParentFamilyContext? _family;
  List<ParentChildWalletItem> _wallets = const <ParentChildWalletItem>[];
  List<ParentReviewItem> _reviews = const <ParentReviewItem>[];
  List<ParentQuestItem> _quests = const <ParentQuestItem>[];
  List<InAppNotificationItem> _notifications = const <InAppNotificationItem>[];
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    _reload(showLoading: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _reload(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading && _family == null) {
      return _SectionScaffold(
        title: 'Семья',
        child: Column(
          children: const [
            _SkeletonCard(height: 96),
            SizedBox(height: 8),
            _SkeletonCard(height: 120),
            SizedBox(height: 8),
            _SkeletonCard(height: 76),
          ],
        ),
      );
    }

    if (_family == null) {
      final session = ref.read(parentSessionProvider).asData?.value;
      final isAdminWithoutFamily =
          session != null &&
          session.role == 'admin' &&
          (session.familyId.trim().isEmpty);
      if (isAdminWithoutFamily) {
        return _SectionScaffold(
          title: 'Администратор',
          child: _AdminWithoutFamilyCard(
            onSignOut: () => ref.read(authActionsProvider).signOut(),
          ),
        );
      }
      return _SectionScaffold(
        title: 'Семья',
        onRefresh: () => _reload(),
        child: _ErrorCard(
          title: 'Не удалось загрузить данные',
          error: _loadError ?? 'Семья не найдена',
          onRetry: () => _reload(),
        ),
      );
    }

    final family = _family!;
    final market = _quests
        .where((q) => q.status == 'active' && q.questType == 'free')
        .toList();
    final total = _wallets.fold<int>(0, (sum, w) => sum + w.balance);

    return _SectionScaffold(
      title: (family.clanName ?? '').trim().isEmpty
          ? 'Семья'
          : family.clanName!.trim(),
      onRefresh: () => _reload(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_refreshing) const LinearProgressIndicator(),
          if (_refreshing) const SizedBox(height: 8),
          _ClanKidsBlock(wallets: _wallets),
          const SizedBox(height: 8),
          _PendingReviewFeed(
            items: _reviews,
            onItemRemoved: (item) {
              setState(() {
                _reviews = _reviews
                    .where(
                      (r) =>
                          !(r.questId == item.questId &&
                              r.childId == item.childId),
                    )
                    .toList();
              });
            },
          ),
          _MetricTile(
            icon: Icons.notifications,
            title: 'Уведомления',
            value: _notifications
                .where((n) => n.status != 'read')
                .length
                .toString(),
            onTap: widget.onOpenNotifications,
          ),
          if (_reviews.isNotEmpty)
            _MetricTile(
              icon: Icons.task_alt,
              title: 'Ждут подтверждения',
              value: _reviews.length.toString(),
              onTap: widget.onOpenQuests,
            ),
          _MetricTile(
            icon: Icons.storefront,
            title: 'Биржа квестов',
            value: market.length.toString(),
            onTap: widget.onOpenQuests,
          ),
          _QuestMarketBlock(quests: _quests, onTap: widget.onOpenQuests),
          _FamilyGoalBlock(
            current: total,
            target: family.goalAmount,
            onTap: widget.onOpenWallet,
          ),
        ],
      ),
    );
  }

  Future<void> _reload({bool showLoading = false, bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading && _family == null) {
        _initialLoading = true;
      } else if (!silent) {
        _refreshing = true;
      }
    });
    try {
      final data = await _loadDashboard(ref);
      if (!mounted) return;
      final hasChanged =
          !_sameFamily(_family, data.family) ||
          !_sameWallets(_wallets, data.wallets) ||
          !_sameReviews(_reviews, data.reviews) ||
          !_sameQuests(_quests, data.quests) ||
          !_sameNotifications(_notifications, data.notifications) ||
          _loadError != null;
      setState(() {
        if (hasChanged) {
          _family = data.family;
          _wallets = data.wallets;
          _reviews = data.reviews;
          _quests = data.quests;
          _notifications = data.notifications;
        }
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          if (!silent) _refreshing = false;
        });
      }
    }
  }

  Future<_ParentDashboardSnapshot> _loadDashboard(WidgetRef ref) async {
    final family = await ref
        .read(parentAccessRepositoryProvider)
        .getFamilyContext();
    if (family == null) {
      return const _ParentDashboardSnapshot(
        family: null,
        wallets: <ParentChildWalletItem>[],
        reviews: <ParentReviewItem>[],
        quests: <ParentQuestItem>[],
        notifications: <InAppNotificationItem>[],
      );
    }

    final results = await Future.wait<dynamic>([
      ref.read(questsRepositoryProvider).getSubmittedForReview(family.familyId),
      ref.read(questsRepositoryProvider).getParentQuests(family.familyId),
      ref.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
      ref
          .read(notificationsRepositoryProvider)
          .listFamilyNotifications(family.familyId),
    ]);

    return _ParentDashboardSnapshot(
      family: family,
      reviews: results[0] as List<ParentReviewItem>,
      quests: results[1] as List<ParentQuestItem>,
      wallets: results[2] as List<ParentChildWalletItem>,
      notifications: results[3] as List<InAppNotificationItem>,
    );
  }

  bool _sameFamily(ParentFamilyContext? a, ParentFamilyContext? b) {
    if (a == null || b == null) return a == b;
    return a.familyId == b.familyId &&
        a.familyCode == b.familyCode &&
        (a.clanName ?? '') == (b.clanName ?? '') &&
        a.goalAmount == b.goalAmount;
  }

  bool _sameWallets(
    List<ParentChildWalletItem> a,
    List<ParentChildWalletItem> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.childId != y.childId ||
          x.displayName != y.displayName ||
          x.balance != y.balance) {
        return false;
      }
    }
    return true;
  }

  bool _sameReviews(List<ParentReviewItem> a, List<ParentReviewItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.questId != y.questId ||
          x.childId != y.childId ||
          x.childName != y.childName ||
          x.title != y.title ||
          x.submittedAt != y.submittedAt ||
          x.evidencePath != y.evidencePath ||
          x.evidenceUrl != y.evidenceUrl) {
        return false;
      }
    }
    return true;
  }

  bool _sameQuests(List<ParentQuestItem> a, List<ParentQuestItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.title != y.title ||
          x.status != y.status ||
          x.questType != y.questType ||
          x.rewardAmount != y.rewardAmount ||
          x.createdAt != y.createdAt ||
          x.distributionType != y.distributionType ||
          x.autoApprove != y.autoApprove ||
          x.timeLimitMinutes != y.timeLimitMinutes ||
          x.scheduleType != y.scheduleType ||
          !_sameStrings(x.scheduleDays, y.scheduleDays)) {
        return false;
      }
    }
    return true;
  }

  bool _sameNotifications(
    List<InAppNotificationItem> a,
    List<InAppNotificationItem> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.type != y.type ||
          x.status != y.status ||
          x.createdAt != y.createdAt) {
        return false;
      }
    }
    return true;
  }

  bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _AdminWithoutFamilyCard extends StatelessWidget {
  const _AdminWithoutFamilyCard({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Аккаунт администратора',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Этот аккаунт не привязан к семье. Для работы используйте веб-админку.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentDashboardSnapshot {
  const _ParentDashboardSnapshot({
    required this.family,
    required this.wallets,
    required this.reviews,
    required this.quests,
    required this.notifications,
  });

  final ParentFamilyContext? family;
  final List<ParentChildWalletItem> wallets;
  final List<ParentReviewItem> reviews;
  final List<ParentQuestItem> quests;
  final List<InAppNotificationItem> notifications;
}

class _ClanKidsBlock extends ConsumerWidget {
  const _ClanKidsBlock({required this.wallets});
  final List<ParentChildWalletItem> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Мой Клан', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (wallets.isEmpty) const Text('Пока нет детей'),
            if (wallets.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: wallets.map((w) {
                    return Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () async {
                              final profile = await ref
                                  .read(parentAccessRepositoryProvider)
                                  .getChildProfile(w.childId);
                              if (!context.mounted) return;
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) {
                                  final stats =
                                      (profile['stats']
                                          as Map<String, dynamic>? ??
                                      <String, dynamic>{});
                                  return AlertDialog(
                                    title: Text(
                                      (profile['displayName'] ?? '').toString(),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Баланс: ${profile['balance'] ?? 0} 🏠',
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Назначено: ${stats['assigned'] ?? 0}',
                                        ),
                                        Text(
                                          'В работе: ${stats['inProgress'] ?? 0}',
                                        ),
                                        Text(
                                          'На проверке: ${stats['onReview'] ?? 0}',
                                        ),
                                        Text(
                                          'Выполнено: ${stats['approved'] ?? 0}',
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('Закрыть'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const CircleAvatar(
                              radius: 24,
                              child: Icon(Icons.child_care),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            w.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text('${w.balance} 🏠'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingReviewFeed extends ConsumerWidget {
  const _PendingReviewFeed({required this.items, required this.onItemRemoved});
  final List<ParentReviewItem> items;
  final ValueChanged<ParentReviewItem> onItemRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ждут подтверждения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...items.take(3).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child:
                          item.evidenceUrl != null &&
                              item.evidenceUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.evidenceUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.image),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${item.childName}: ${item.title}')),
                    IconButton(
                      tooltip: 'Принять',
                      onPressed: () async {
                        await ref
                            .read(questsRepositoryProvider)
                            .reviewSubmission(
                              questId: item.questId,
                              childId: item.childId,
                              approve: true,
                              comment: '',
                            );
                        onItemRemoved(item);
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                    IconButton(
                      tooltip: 'Отклонить',
                      onPressed: () async {
                        final commentCtl = TextEditingController();
                        final comment = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('Комментарий к отклонению'),
                              content: TextField(
                                controller: commentCtl,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Что нужно переделать',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(
                                    ctx,
                                  ).pop(commentCtl.text.trim()),
                                  child: const Text('Отклонить'),
                                ),
                              ],
                            );
                          },
                        );
                        if (comment == null) return;
                        await ref
                            .read(questsRepositoryProvider)
                            .reviewSubmission(
                              questId: item.questId,
                              childId: item.childId,
                              approve: false,
                              comment: comment,
                            );
                        onItemRemoved(item);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FamilyGoalBlock extends StatelessWidget {
  const _FamilyGoalBlock({
    required this.current,
    required this.target,
    this.onTap,
  });
  final int current;
  final int target;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Общая цель',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('$current / $target 🏠'),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestMarketBlock extends StatelessWidget {
  const _QuestMarketBlock({required this.quests, this.onTap});
  final List<ParentQuestItem> quests;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final market = quests
        .where((q) => q.status == 'active' && q.questType == 'free')
        .take(6)
        .toList();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Биржа квестов',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (market.isEmpty) const Text('Свободных квестов нет'),
              ...market.map(
                (q) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt),
                  title: Text(q.title),
                  trailing: Text('+${q.rewardAmount}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.child,
    this.onRefresh,
  });

  final String title;
  final Widget child;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(height: height, width: double.infinity),
    );
  }
}
