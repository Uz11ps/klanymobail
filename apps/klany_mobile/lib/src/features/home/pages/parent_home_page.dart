import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../child_soft_ui.dart';

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
    } catch (_) {}
  }

  Future<void> _registerDevice() async {
    final identity = await DeviceIdentityStore.getOrCreate();
    final userId = ref.read(parentSessionProvider).asData?.value?.userId;
    if (userId == null) return;

    final platform = _platformName();
    final pushToken = await Fcm.getToken();
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

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kChildSurfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.storefront, color: kChildBrandBlue),
              title: const Text('Магазин'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentShopPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet,
                color: kChildBrandBlue,
              ),
              title: const Text('Кошелёк'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentWalletsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield, color: kChildBrandBlue),
              title: const Text('Штаб / Семья'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentFamilySettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: kChildBrandBlue),
              title: const Text('Уведомления'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.school, color: kChildBrandBlue),
              title: const Text('Показать обучение'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await showOnboardingTourDialog(
                  context: context,
                  title: parentTourTitle,
                  steps: parentTourSteps,
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFD83A3A)),
              title: const Text('Выйти'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(authActionsProvider).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ParentDashboardPage(
        onOpenQuests: () => setState(() => _index = 1),
        onOpenShop: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ParentShopPage()),
          );
        },
        onOpenWallet: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ParentWalletsPage(),
            ),
          );
        },
        onOpenNotifications: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
          );
        },
      ),
      const ParentQuestsPage(),
      const ParentAccessRequestsPage(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: kChildSurfaceSoft,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: _BottomClanBar(
          currentIndex: _index,
          pendingRequests: _pendingRequestsCount,
          onSelected: (i) => setState(() => _index = i),
          onOpenSettings: () => _openSettingsSheet(context),
        ),
      ),
    );
  }
}

class _BottomClanBar extends StatelessWidget {
  const _BottomClanBar({
    required this.currentIndex,
    required this.onSelected,
    required this.onOpenSettings,
    required this.pendingRequests,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenSettings;
  final int pendingRequests;

  Widget _buildPill({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    final bg = selected ? kChildBrandBlue : kChildSurfaceWhite;
    final fg = selected ? Colors.white : kChildBrandBlue;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kChildBrandBlue, width: 1.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: fg, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (badge != null) Positioned(top: 0, right: 8, child: badge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Row(
          children: [
            _buildPill(
              selected: currentIndex == 0,
              icon: Icons.home_filled,
              label: 'Клан',
              onTap: () => onSelected(0),
            ),
            _buildPill(
              selected: currentIndex == 1,
              icon: Icons.task_alt,
              label: 'Биржа',
              onTap: () => onSelected(1),
            ),
            _buildPill(
              selected: currentIndex == 2,
              icon: Icons.mark_email_unread_outlined,
              label: 'Заявки',
              onTap: () => onSelected(2),
              badge: pendingRequests > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD83A3A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingRequests',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Material(
                color: kChildSurfaceWhite,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onOpenSettings,
                  child: Container(
                    width: 52,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: kChildOutline, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.settings_outlined,
                      color: kChildInkMuted,
                    ),
                  ),
                ),
              ),
            ),
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
    final clanName = (_family?.clanName ?? '').trim().isEmpty
        ? 'Семья'
        : _family!.clanName!.trim();
    const parentName = 'Глава Клана';

    if (_initialLoading && _family == null) {
      return _buildScaffold(
        title: 'Семья',
        parentName: parentName,
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
        return _buildScaffold(
          title: 'Администратор',
          parentName: parentName,
          child: _AdminWithoutFamilyCard(
            onSignOut: () => ref.read(authActionsProvider).signOut(),
          ),
        );
      }
      return _buildScaffold(
        title: 'Семья',
        parentName: parentName,
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
    final unreadNotifs =
        _notifications.where((n) => n.status != 'read').length;

    return _buildScaffold(
      title: clanName,
      parentName: parentName,
      totalBalance: total,
      childrenCount: _wallets.length,
      pendingReviews: _reviews.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_refreshing) ...[
            const LinearProgressIndicator(
              color: kChildBrandBlue,
              backgroundColor: kChildOutline,
            ),
            const SizedBox(height: 8),
          ],
          _ClanKidsBlock(wallets: _wallets),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 14),
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
          ],
          const SizedBox(height: 14),
          _BrandMetricRow(
            items: [
              _BrandMetric(
                icon: Icons.notifications_outlined,
                label: 'Уведомления',
                value: unreadNotifs.toString(),
                color: kChildAccentOrange,
                onTap: widget.onOpenNotifications,
              ),
              _BrandMetric(
                icon: Icons.task_alt,
                label: 'Биржа',
                value: market.length.toString(),
                color: kChildBrandBlue,
                onTap: widget.onOpenQuests,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GradientGoalBar(
            current: total,
            target: family.goalAmount,
            onTap: widget.onOpenWallet,
          ),
          const SizedBox(height: 14),
          _QuestMarketBlock(quests: _quests, onTap: widget.onOpenQuests),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScaffold({
    required String title,
    required String parentName,
    int totalBalance = 0,
    int childrenCount = 0,
    int pendingReviews = 0,
    required Widget child,
  }) {
    final body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: kChildInk,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: kChildInk,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => _reload(),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ParentHeroCard(
                  name: parentName,
                  clanTitle: title,
                  totalBalance: totalBalance,
                  childrenCount: childrenCount,
                  pendingReviews: pendingReviews,
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ],
    );

    return Container(
      color: kChildSurfaceSoft,
      child: RefreshIndicator(
        onRefresh: () => _reload(),
        child: body,
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
      setState(() => _loadError = e);
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
          x.balance != y.balance) { return false; }
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
          x.evidenceUrl != y.evidenceUrl) { return false; }
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
          !_sameStrings(x.scheduleDays, y.scheduleDays)) { return false; }
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
          x.createdAt != y.createdAt) { return false; }
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

// ─── Hero card ────────────────────────────────────────────────────────────────

class _ParentHeroCard extends StatelessWidget {
  const _ParentHeroCard({
    required this.name,
    required this.clanTitle,
    this.totalBalance = 0,
    this.childrenCount = 0,
    this.pendingReviews = 0,
  });

  final String name;
  final String clanTitle;
  final int totalBalance;
  final int childrenCount;
  final int pendingReviews;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kChildBrandBlue, Color(0xFF5A8EFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x471E2D52),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 14,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 10,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Глава семьи • $clanTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMetric(
                          title: 'БАЛАНС',
                          value: '$totalBalance',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroMetric(
                          title: 'ДЕТИ',
                          value: childrenCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroMetric(
                          title: 'НА ПРОВЕР.',
                          value: pendingReviews.toString(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kids block ───────────────────────────────────────────────────────────────

class _ClanKidsBlock extends ConsumerWidget {
  const _ClanKidsBlock({required this.wallets});
  final List<ParentChildWalletItem> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kChildBrandBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.people,
                  color: kChildBrandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'МОЙ КЛАН',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (wallets.isEmpty)
            const Text(
              'Пока нет детей. Пригласите ребёнка по ключу клана.',
              style: TextStyle(fontSize: 13, color: kChildInkMuted),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: wallets.map((w) {
                  final initial = w.displayName.isEmpty
                      ? '?'
                      : w.displayName.characters.first.toUpperCase();
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final profile = await ref
                          .read(parentAccessRepositoryProvider)
                          .getChildProfile(w.childId);
                      if (!context.mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) {
                          final stats =
                              (profile['stats'] as Map<String, dynamic>? ??
                                  <String, dynamic>{});
                          return AlertDialog(
                            title: Text(
                              (profile['displayName'] ?? '').toString(),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Баланс: ${profile['balance'] ?? 0} монет'),
                                const SizedBox(height: 8),
                                Text('Назначено: ${stats['assigned'] ?? 0}'),
                                Text('В работе: ${stats['inProgress'] ?? 0}'),
                                Text(
                                  'На проверке: ${stats['onReview'] ?? 0}',
                                ),
                                Text('Выполнено: ${stats['approved'] ?? 0}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Закрыть'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: kChildBrandBlue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: kChildBrandBlue.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: kChildBrandBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            w.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${w.balance} монет',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kChildInkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Pending reviews ──────────────────────────────────────────────────────────

class _PendingReviewFeed extends ConsumerWidget {
  const _PendingReviewFeed({required this.items, required this.onItemRemoved});
  final List<ParentReviewItem> items;
  final ValueChanged<ParentReviewItem> onItemRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ChildSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kChildAccentOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.rate_review_outlined,
                  color: kChildAccentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'НА ПРОВЕРКЕ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kChildAccentOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kChildAccentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.take(3).map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: kChildSurfaceSoft,
                      border: Border.all(color: kChildOutline),
                    ),
                    child: item.evidenceUrl != null &&
                            item.evidenceUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.evidenceUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.image_outlined,
                            color: kChildInkMuted,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.childName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kChildBrandBlue,
                          ),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: kChildInk,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    icon: const Icon(
                      Icons.check_circle,
                      color: kChildAccentGreen,
                      size: 22,
                    ),
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
                                onPressed: () => Navigator.of(ctx)
                                    .pop(commentCtl.text.trim()),
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
                    icon: const Icon(
                      Icons.cancel,
                      color: Color(0xFFD83A3A),
                      size: 22,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Brand metric row ─────────────────────────────────────────────────────────

class _BrandMetric {
  const _BrandMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
}

class _BrandMetricRow extends StatelessWidget {
  const _BrandMetricRow({required this.items});
  final List<_BrandMetric> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _BrandMetricCard(metric: items[i])),
        ],
      ],
    );
  }
}

class _BrandMetricCard extends StatelessWidget {
  const _BrandMetricCard({required this.metric});
  final _BrandMetric metric;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: metric.onTap,
        child: ChildSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(metric.icon, color: metric.color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                metric.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kChildInkMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.value,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: metric.color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Goal bar ─────────────────────────────────────────────────────────────────

class _GradientGoalBar extends StatelessWidget {
  const _GradientGoalBar({
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
    final percent = (progress * 100).toInt();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8BC34A), kChildBrandBlue],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x281E63D8),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ОБЩАЯ ЦЕЛЬ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.28),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                target > 0
                    ? '$current / $target монет'
                    : 'Общая цель не задана',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quest market ─────────────────────────────────────────────────────────────

class _QuestMarketBlock extends StatelessWidget {
  const _QuestMarketBlock({required this.quests, this.onTap});
  final List<ParentQuestItem> quests;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final market = quests
        .where((q) => q.status == 'active' && q.questType == 'free')
        .take(5)
        .toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kChildBrandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.bolt,
                      color: kChildBrandBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'БИРЖА ЗАДАЧ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: kChildBrandBlue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (market.isEmpty)
                const Text(
                  'Свободных задач нет',
                  style: TextStyle(fontSize: 13, color: kChildInkMuted),
                )
              else
                ...market.map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kChildBrandBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: kChildInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kChildAccentGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${q.rewardAmount}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kChildAccentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Misc widgets ─────────────────────────────────────────────────────────────

class _AdminWithoutFamilyCard extends StatelessWidget {
  const _AdminWithoutFamilyCard({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Аккаунт администратора',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kChildInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Этот аккаунт не привязан к семье. Для работы используйте веб-админку.',
            style: TextStyle(fontSize: 14, color: kChildInkMuted),
          ),
          const SizedBox(height: 16),
          ClanPrimaryButton(
            label: 'Выйти',
            icon: Icons.logout,
            onPressed: onSignOut,
          ),
        ],
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
    return ChildSoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kChildInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 13, color: kChildInkMuted),
          ),
          const SizedBox(height: 16),
          ClanPrimaryButton(
            label: 'Повторить',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kChildSurfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kChildOutline),
      ),
    );
  }
}
