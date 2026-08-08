import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../auth/auth_actions.dart';
import '../../auth/device_identity.dart';
import '../../auth/parent_access_repository.dart';
import '../../auth/parent_session.dart';
import '../../notifications/fcm.dart';
import '../../notifications/notifications_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';
import '../../quests/pages/parent_quests_page.dart';
import '../../quests/pages/parent_task_exchange_page.dart';
import '../../quests/quests_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/pages/parent_wallets_page.dart';
import '../../wallet/wallet_repository.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/klany_live_poll.dart';
import '../../../core/storage_presign.dart';
import '../../../core/value_bump.dart';
import '../avatar_store.dart';
import '../child_soft_ui.dart';
import '../parent_main_bottom_bar.dart';
import 'parent_family_settings_page.dart';

// Родительский home: каркас как у ChildHomePage (SizedBox.expand, LayoutBuilder,
// IndexedStack + StackFit.expand); дашборд — RefreshIndicator + ListView. Figma 0-81 + API.
// ═══════════════════════════════════════════════════════════════════════════

String _formatThousandsRu(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

// ─── Корневая страница (оболочка + нижняя навигация) ───────────────────────

class ParentHomePage extends ConsumerStatefulWidget {
  const ParentHomePage({super.key});

  @override
  ConsumerState<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends ConsumerState<ParentHomePage>
    with KlanyLivePollConsumerMixin {
  int _index = 0;
  int _registerAttempts = 0;
  int _pendingRequestsCount = 0;

  @override
  void onKlanyLivePoll({bool silent = true}) {
    _refreshPendingRequests();
  }

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

  ParentMainTab get _mainTab => switch (_index) {
        1 => ParentMainTab.exchange,
        2 => ParentMainTab.shop,
        3 => ParentMainTab.settings,
        _ => ParentMainTab.home,
      };

  void _onMainTab(ParentMainTab tab) {
    setState(() {
      _index = switch (tab) {
        ParentMainTab.home => 0,
        ParentMainTab.exchange => 1,
        ParentMainTab.shop => 2,
        ParentMainTab.settings => 3,
      };
    });
  }

  void _goHomeTab() => setState(() => _index = 0);

  void _openEconomy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ParentQuestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ParentDashboardView(
        onOpenQuests: () => setState(() => _index = 1),
        onOpenEconomy: _openEconomy,
        onOpenWallet: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ParentWalletsPage()),
          );
        },
      ),
      ParentTaskExchangePage(onBack: _goHomeTab, embeddedInHomeTab: true),
      ParentShopPage(onBack: _goHomeTab),
      ParentFamilySettingsPage(onBack: _goHomeTab),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: SizedBox.expand(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final maxH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height;
                return SizedBox(
                  width: maxW,
                  height: maxH,
                  child: IndexedStack(
                    index: _index,
                    sizing: StackFit.expand,
                    children: pages,
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: _index == 2
              ? null
              : ParentMainBottomBar(
                  current: _mainTab,
                  onSelected: _onMainTab,
                ),
        ),
      ),
    );
  }
}

// ─── Нижняя «таблетка» — те же размеры и сетка, что `_ShopBottomBar` (без смены ширины центра).
class _DashboardSnapshot {
  const _DashboardSnapshot({
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

class _ParentDashboardView extends ConsumerStatefulWidget {
  const _ParentDashboardView({
    required this.onOpenQuests,
    required this.onOpenEconomy,
    required this.onOpenWallet,
  });

  final VoidCallback onOpenQuests;
  final VoidCallback onOpenEconomy;
  final VoidCallback onOpenWallet;

  @override
  ConsumerState<_ParentDashboardView> createState() =>
      _ParentDashboardViewState();
}

class _ParentDashboardViewState extends ConsumerState<_ParentDashboardView>
    with KlanyLivePollConsumerMixin {
  bool _initialLoading = true;
  bool _refreshing = false;
  ParentFamilyContext? _family;
  List<ParentChildWalletItem> _wallets = const [];
  List<ParentReviewItem> _reviews = const [];
  List<ParentQuestItem> _quests = const [];
  List<InAppNotificationItem> _notifications = const [];

  @override
  void onKlanyLivePoll({bool silent = true}) {
    _reload(silent: true);
  }

  @override
  void initState() {
    super.initState();
    _reload(showLoading: true);
  }

  String _dashboardFeedDigest() {
    const cap = 24;
    final ns = _notifications
        .take(cap)
        .map(
          (n) =>
              '${n.id}:${n.type}:${n.status}:${n.createdAt.millisecondsSinceEpoch}',
        )
        .join('|');
    final rs = _reviews
        .take(cap)
        .map(
          (r) =>
              '${r.questId}:${r.submittedAt?.millisecondsSinceEpoch ?? 0}:${r.title}',
        )
        .join('|');
    return '$ns#$rs';
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
      final data = await _fetchSnapshot(ref);
      if (!mounted) return;
      final changed =
          !_sameFamily(_family, data.family) ||
          !_sameWallets(_wallets, data.wallets) ||
          !_sameReviews(_reviews, data.reviews) ||
          !_sameQuests(_quests, data.quests) ||
          !_sameNotifications(_notifications, data.notifications);
      setState(() {
        if (changed) {
          _family = data.family;
          _wallets = data.wallets;
          _reviews = data.reviews;
          _quests = data.quests;
          _notifications = data.notifications;
        }
      });
    } catch (e) {
      if (!mounted) return;
      context.showKlanyNetworkErrorSnackBar(e);
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          if (!silent) _refreshing = false;
        });
      }
    }
  }

  Future<_DashboardSnapshot> _fetchSnapshot(WidgetRef r) async {
    final family = await r
        .read(parentAccessRepositoryProvider)
        .getFamilyContext();
    if (family == null) {
      return const _DashboardSnapshot(
        family: null,
        wallets: <ParentChildWalletItem>[],
        reviews: <ParentReviewItem>[],
        quests: <ParentQuestItem>[],
        notifications: <InAppNotificationItem>[],
      );
    }

    final results = await Future.wait<dynamic>([
      r.read(questsRepositoryProvider).getSubmittedForReview(family.familyId),
      r.read(questsRepositoryProvider).getParentQuests(family.familyId),
      r.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
      r
          .read(notificationsRepositoryProvider)
          .listFamilyNotifications(family.familyId),
    ]);

    return _DashboardSnapshot(
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
        a.goalAmount == b.goalAmount &&
        a.rublesPer10Coins == b.rublesPer10Coins;
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

  Future<void> _openChildSheet(ParentChildWalletItem wallet) async {
    final activeForChild = _quests
        .where(
          (q) =>
              q.status == 'active' &&
              (q.distributionType == 'exchange' ||
                  q.childIds.contains(wallet.childId)),
        )
        .length;
    final reviewsForChild = _reviews
        .where((r) => r.childId == wallet.childId)
        .toList();

    final screen = MediaQuery.sizeOf(context);
    final isWide = screen.width >= 700;

    if (isWide) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: screen.height * 0.78,
            ),
            child: _ChildDetailsPanel(
              wallet: wallet,
              activeForChild: activeForChild,
              reviewsForChild: reviewsForChild,
              onOpenWallet: () {
                Navigator.of(dialogCtx).pop();
                widget.onOpenWallet();
              },
              onOpenQuests: () {
                Navigator.of(dialogCtx).pop();
                widget.onOpenQuests();
              },
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Иначе M3 добавляет свой drag-handle — визуально «двоится» с полоской в _ChildDetailsPanel.
      showDragHandle: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollController) => _ChildDetailsPanel(
          wallet: wallet,
          activeForChild: activeForChild,
          reviewsForChild: reviewsForChild,
          scrollController: scrollController,
          bottomPadding: 20 + MediaQuery.viewPaddingOf(sheetCtx).bottom,
          onOpenWallet: () {
            Navigator.of(sheetCtx).pop();
            widget.onOpenWallet();
          },
          onOpenQuests: () {
            Navigator.of(sheetCtx).pop();
            widget.onOpenQuests();
          },
        ),
      ),
    );
  }

  int _bellBadgeCount() {
    final reverse = _quests
        .where(
          (q) => q.status == 'active' && q.distributionType == 'reverse',
        )
        .length;
    final unread = _notifications.where((n) => n.status != 'read').length;
    final n = unread + reverse;
    return n > 99 ? 99 : n;
  }

  Widget _dashboardHeader(BuildContext context) {
    final bellBadge = _bellBadgeCount();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'CLAN CAPITAL',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4563B1),
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.14),
          child: Tooltip(
            message:
                'Уведомления: лента семьи и задачи от ребёнка к родителю',
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: ValueBumpWrap(
                changeKey: bellBadge,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        color: kChildInk, size: 24),
                    if (bellBadge > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD83A3A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            bellBadge > 9 ? '9+' : '$bellBadge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.14),
          child: InkWell(
            onTap: () => _reload(),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SvgPicture.asset(
                  'assets/figma/nav_refresh.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    kChildInk,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = 40 +
        MediaQuery.viewPaddingOf(context).bottom +
        24 +
        ParentMainBottomBarLayout.scaledPillHeight(context) +
        context.klanySize(16) +
        24;

    late final List<Widget> listChildren;
    if (_initialLoading && _family == null) {
      listChildren = [
        _dashboardHeader(context),
        const SizedBox(height: 25),
        const _SkeletonBlock(height: 80),
        const SizedBox(height: 10),
        const _SkeletonBlock(height: 80),
        const SizedBox(height: 10),
        const _SkeletonBlock(height: 120),
      ];
    } else if (_family == null) {
      final session = ref.read(parentSessionProvider).asData?.value;
      final isAdminNoFamily =
          session != null &&
          session.role == 'admin' &&
          session.familyId.trim().isEmpty;
      listChildren = [
        _dashboardHeader(context),
        const SizedBox(height: 25),
        if (isAdminNoFamily)
          _AdminNoFamilyCard(
            onSignOut: () => ref.read(authActionsProvider).signOut(),
          ),
      ];
    } else {
      final activeQuests = _quests.where((q) => q.status == 'active').toList();
      final totalCoins = _wallets.fold<int>(0, (s, w) => s + w.balance);
      listChildren = [
        _dashboardHeader(context),
        const SizedBox(height: 25),
        if (_refreshing) ...[
          const LinearProgressIndicator(
            color: kChildBrandBlue,
            backgroundColor: kChildOutline,
          ),
          const SizedBox(height: 8),
        ],
        _MembersStrip(
          wallets: _wallets,
          onChildTap: _openChildSheet,
        ),
        const _FigmaSectionTitle('Инфо-панель'),
        const SizedBox(height: 11),
        _InfoPanelStrip(
          inProgress: activeQuests.length,
          onReview: _reviews.length,
          goalTotal: totalCoins,
          inProgressBumpKey: activeQuests.length,
          onReviewBumpKey: _reviews.length,
          goalBumpKey: totalCoins,
          onQuestsTap: widget.onOpenQuests,
          onGoalTap: widget.onOpenEconomy,
        ),
        const _FigmaSectionTitle('Недавние события', bottomPadding: 18),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ValueBumpWrap(
            changeKey: _dashboardFeedDigest(),
            alignment: Alignment.topCenter,
            // Слабее зум — меньше риска наехать на заголовок без жёсткого ClipRect
            beginScale: 1.038,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _MergedActivityFeed(
                notifications: _notifications,
                reviews: _reviews,
                wallets: _wallets,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ];
    }

    return RefreshIndicator(
      onRefresh: () => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad),
        children: listChildren,
      ),
    );
  }
}

// ─── Карточки макета ────────────────────────────────────────────────────────

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});
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

class _NeuSurfaceCard extends StatelessWidget {
  const _NeuSurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ClanCapitalUi.neuCard(radius: 26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.value,
    this.valueBumpKey,
    this.footer,
    this.onTap,
    required this.background,
    required this.boxShadows,
  });

  final String title;
  final String value;
  /// Анимация «дёргания» строки числа при смене этого ключа (напр. счётчик).
  final Object? valueBumpKey;
  final String? footer;
  final VoidCallback? onTap;
  final Color background;
  final List<BoxShadow> boxShadows;

  @override
  Widget build(BuildContext context) {
    final bump = valueBumpKey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 159,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: boxShadows,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              bump == null
                  ? Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    )
                  : ValueBumpWrap(
                      changeKey: bump,
                      alignment: Alignment.center,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                Text(
                  footer!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF515151),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPanelStrip extends StatelessWidget {
  const _InfoPanelStrip({
    required this.inProgress,
    required this.onReview,
    required this.goalTotal,
    this.inProgressBumpKey,
    this.onReviewBumpKey,
    this.goalBumpKey,
    this.onQuestsTap,
    this.onGoalTap,
  });

  final int inProgress;
  final int onReview;
  final int goalTotal;
  final Object? inProgressBumpKey;
  final Object? onReviewBumpKey;
  final Object? goalBumpKey;
  final VoidCallback? onQuestsTap;
  final VoidCallback? onGoalTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _InfoTile(
            title: 'В работе',
            value: '$inProgress',
            valueBumpKey: inProgressBumpKey,
            footer: 'КЛАН / ВСЕ',
            onTap: onQuestsTap,
            background: const Color(0xFFC1D8F5),
            boxShadows: [
              BoxShadow(
                color: const Color(0xFFC1DCFF).withValues(alpha: 0.45),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: const Color(0xFFBFD9FF).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _InfoTile(
            title: 'На проверке',
            value: '$onReview',
            valueBumpKey: onReviewBumpKey,
            background: const Color(0xFFF9E8A5),
            boxShadows: [
              BoxShadow(
                color: const Color(0xFFFEF1B8).withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: const Color(0xFFFEF1B8).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _InfoTile(
            title: 'Общая цель',
            value: _formatThousandsRu(goalTotal),
            valueBumpKey: goalBumpKey,
            footer: 'Накопления',
            onTap: onGoalTap,
            background: const Color(0xFFD9F6C2),
            boxShadows: [
              BoxShadow(
                color: const Color(0xFFE6F7D9).withValues(alpha: 0.45),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: const Color(0xFFD4FFB3).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberAvatarCard extends StatelessWidget {
  const _MemberAvatarCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4563B1).withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.29),
              width: selected ? 1.2 : 0.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 73, height: 73, child: avatar),
              const SizedBox(height: 10),
              SizedBox(
                width: 88,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.0,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
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

class _MembersStrip extends StatefulWidget {
  const _MembersStrip({
    required this.wallets,
    required this.onChildTap,
  });

  final List<ParentChildWalletItem> wallets;
  final ValueChanged<ParentChildWalletItem> onChildTap;

  @override
  State<_MembersStrip> createState() => _MembersStripState();
}

class _MembersStripState extends State<_MembersStrip> {
  int _selected = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.wallets.isEmpty) {
      return const SizedBox.shrink();
    }
    final chips = widget.wallets.asMap().entries.map((e) {
      final name = e.value.displayName.trim().isEmpty
          ? 'Ребёнок'
          : e.value.displayName.trim();
      final initial = name.characters.first.toUpperCase();
      return _MemberAvatarCard(
        label: name,
        selected: _selected == e.key,
        onTap: () {
          setState(() => _selected = e.key);
          widget.onChildTap(e.value);
        },
        avatar: ClipOval(
          child: UserAvatar(
            userKey: 'child:${e.value.childId}',
            size: 73,
            fallbackText: initial,
            remoteImageUrl: e.value.avatarImageUrl,
            remoteDiskCacheKey:
                (e.value.avatarObjectKey ?? '').trim().isEmpty
                    ? null
                    : storageObjectDiskCacheKey(
                        'member-avatars',
                        e.value.avatarObjectKey!.trim(),
                      ),
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _FigmaSectionTitle extends StatelessWidget {
  const _FigmaSectionTitle(this.text, {this.bottomPadding = 4});
  final String text;
  /// Отступ под заголовком до следующего блока списка.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20, bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: kChildOutline.withValues(alpha: 0.9)),
          const SizedBox(height: 15),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEventCard extends StatelessWidget {
  const _RecentEventCard({required this.avatar, required this.textBlock});

  final Widget avatar;
  final Widget textBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(child: textBlock),
        ],
      ),
    );
  }
}

class _MergedActivityFeed extends StatelessWidget {
  const _MergedActivityFeed({
    required this.notifications,
    required this.reviews,
    required this.wallets,
  });

  /// После объединения уведомлений и «на проверке» показываем не больше стольких строк.
  static const int _kRecentEventsMaxItems = 10;

  final List<InAppNotificationItem> notifications;
  final List<ParentReviewItem> reviews;
  final List<ParentChildWalletItem> wallets;

  static const _feedName = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    height: 1.35,
  );
  static const _feedBody = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    height: 1.35,
  );
  static final _feedMeta = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: kChildInkMuted.withValues(alpha: 0.9),
    height: 1.35,
  );

  /// Тип события в едином виде для сравнения (бекенд может отдавать точки или подчёркивания).
  static String _eventType(InAppNotificationItem n) =>
      n.type.replaceAll('.', '_').trim();

  /// Одна строка ленты на логическое событие: бэкенд создаёт копию на каждого родителя
  /// (один и тот же `purchaseId` / квест и т.д.).
  static String _recentFeedDedupeKey(InAppNotificationItem n) {
    final type = _eventType(n);
    final p = n.payload;

    switch (type) {
      case 'shop_purchase_requested':
      case 'shop_purchase_approved':
      case 'shop_purchase_rejected':
        final pid = (p['purchaseId'] ?? '').toString().trim();
        if (pid.isNotEmpty) return '$type|$pid';
      case 'quest_submitted':
      case 'quest_approved':
      case 'quest_rejected':
        final qid = (p['questId'] ?? '').toString().trim();
        final cid = (p['childId'] ?? '').toString().trim();
        if (qid.isNotEmpty && cid.isNotEmpty) return '$type|$qid|$cid';
      case 'wallet_adjusted':
        final adj = (p['adjustmentId'] ?? '').toString().trim();
        if (adj.isNotEmpty) return '$type|$adj';
      default:
        break;
    }
    return 'id|${n.id}';
  }

  static List<InAppNotificationItem> _dedupeNotificationsRecent(
    List<InAppNotificationItem> items,
  ) {
    final best = <String, InAppNotificationItem>{};
    for (final n in items) {
      final key = _recentFeedDedupeKey(n);
      final prev = best[key];
      if (prev == null || n.createdAt.isAfter(prev.createdAt)) {
        best[key] = n;
      }
    }
    return best.values.toList();
  }

  /// Первая буква имени — заглавная (остальное без «исправления» регистра).
  static String _displayActorName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.length == 1) return t.toUpperCase();
    return '${t.substring(0, 1).toUpperCase()}${t.substring(1)}';
  }

  static IconData _iconForNotification(InAppNotificationItem n) {
    final t = _eventType(n);
    switch (t) {
      case 'shop_purchase_requested':
        return Icons.add_shopping_cart_outlined;
      case 'shop_purchase_approved':
        return Icons.check_circle_outline_rounded;
      case 'shop_purchase_rejected':
        return Icons.cancel_outlined;
      case 'quest_submitted':
        return Icons.outbound_rounded;
      case 'quest_approved':
        return Icons.task_alt_rounded;
      case 'quest_rejected':
        return Icons.highlight_off_rounded;
      case 'wallet_adjusted':
        return Icons.account_balance_wallet_outlined;
      case 'access_request':
      case 'child_access_requested':
        return Icons.how_to_reg_outlined;
      case 'subscription_expiring':
        return Icons.event_repeat_outlined;
      default:
        if (t.startsWith('family_goal')) return Icons.flag_circle_outlined;
        if (t.startsWith('quest_')) return Icons.assignment_turned_in_outlined;
        if (t.startsWith('shop_')) return Icons.shopping_bag_outlined;
        if (t.startsWith('wallet_')) {
          return Icons.account_balance_wallet_outlined;
        }
        if (t.startsWith('access_')) {
          return Icons.person_add_alt_1_outlined;
        }
        if (t.startsWith('family_')) return Icons.groups_outlined;
        return Icons.notifications_none_rounded;
    }
  }

  /// Имя в ленте: сначала payload (после бэкенд-обогащения), иначе кошелёк ребёнка по childId.
  static String _resolvedActorName(
    InAppNotificationItem n,
    Map<String, ParentChildWalletItem> walletByChildId,
  ) {
    final fromPayload = (n.payload['childName']?.toString() ??
            n.payload['displayName']?.toString() ??
            n.payload['actorName']?.toString() ??
            '')
        .trim();
    if (fromPayload.isNotEmpty) return _displayActorName(fromPayload);
    final id =
        (n.payload['childId']?.toString() ?? n.payload['actorId']?.toString() ?? '')
            .trim();
    if (id.isEmpty) return '';
    return _displayActorName((walletByChildId[id]?.displayName ?? '').trim());
  }

  static Widget _notificationAvatar(
    InAppNotificationItem n,
    String actorName,
    Map<String, ParentChildWalletItem> walletByChildId,
  ) {
    final childId =
        (n.payload['childId']?.toString() ?? n.payload['actorId']?.toString() ?? '')
            .trim();
    if (childId.isNotEmpty) {
      final fb = actorName.trim().isEmpty
          ? '?'
          : actorName.trim().characters.first.toUpperCase();
      final w = walletByChildId[childId];
      final imageKeyWallet = (w?.avatarObjectKey ?? '').trim();
      final imageKeyPayload =
          (n.payload['avatarObjectKey']?.toString() ?? '').trim();
      final imageKeyRaw =
          imageKeyWallet.isNotEmpty ? imageKeyWallet : imageKeyPayload;
      return ClipOval(
        child: UserAvatar(
          userKey: 'child:$childId',
          size: 70,
          fallbackText: fb,
          remoteImageUrl: w?.avatarImageUrl,
          remoteDiskCacheKey: imageKeyRaw.isEmpty
              ? null
              : storageObjectDiskCacheKey('member-avatars', imageKeyRaw),
        ),
      );
    }
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: kChildBrandBlue.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(_iconForNotification(n), size: 28, color: kChildBrandBlue),
    );
  }

  /// Подпись товара в магазинных уведомлениях.
  static String _productLine(InAppNotificationItem n) {
    return (n.payload['productTitle'] ?? n.payload['title'] ?? '')
        .toString()
        .trim();
  }

  /// Человекочитаемая строка для неизвестного типа (никогда не показываем сырой ключ бекенда).
  static String _friendlyUnknownEventLabel(String rawType) {
    final key = rawType.replaceAll('.', '_').toLowerCase().trim();
    const map = <String, String>{
      'shop_purchase_requested': 'Новый запрос на покупку',
      'shop_purchase_approved': 'Покупка одобрена',
      'shop_purchase_rejected': 'Покупка отклонена',
      'child_access_requested': 'Запрос на доступ к семье',
      'subscription_expiring': 'Скоро окончится подписка',
      'account_recovery_requested': 'Запрос на восстановление доступа',
    };
    return map[key] ?? 'Обновление в семье';
  }

  static bool _isFemale(String name) {
    if (name.isEmpty) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('а') || lower.endsWith('я');
  }

  static Widget _notificationTextColumn(
    InAppNotificationItem n,
    String actorName,
  ) {
    final type = _eventType(n);
    final title =
        (n.payload['title']?.toString() ??
                n.payload['questTitle']?.toString() ??
                n.payload['productTitle']?.toString() ??
                '')
            .trim();
    final reward =
        n.payload['rewardAmount']?.toString() ??
        n.payload['amount']?.toString() ??
        n.payload['totalPrice']?.toString() ??
        n.payload['price']?.toString();

    if (type == 'shop_purchase_requested') {
      final product = _productLine(n);
      final nm = actorName.trim();
      final label = nm.isEmpty ? 'Ребёнок' : nm;
      final fem = _isFemale(label);
      final verb = fem ? 'запросила покупку' : 'запросил покупку';

      final priceSuffix =
          reward != null && reward.isNotEmpty ? '($reward монет)' : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: _feedBody,
              children: [
                TextSpan(text: label, style: _feedName),
                const TextSpan(text: ' — '),
                TextSpan(text: verb),
                if (product.isNotEmpty) ...[
                  const TextSpan(text: ' «'),
                  TextSpan(
                    text: product,
                    style: _feedBody.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: '»'),
                ],
              ],
            ),
          ),
          if (priceSuffix != null) ...[
            const SizedBox(height: 4),
            Text(priceSuffix, style: _feedMeta),
          ],
        ],
      );
    }

    if (type == 'shop_purchase_approved' || type == 'shop_purchase_rejected') {
      final product = _productLine(n);
      final nm = actorName.trim();
      final rejected = type == 'shop_purchase_rejected';
      final priceSuffix =
          reward != null && reward.isNotEmpty ? '($reward монет)' : null;

      Widget mainLine;
      if (nm.isEmpty) {
        if (product.isEmpty) {
          mainLine = Text(
            rejected ? 'Заявка на покупку отклонена' : 'Заявка на покупку одобрена',
            style: _feedBody,
          );
        } else {
          final ending = rejected ? 'отклонена' : 'одобрена';
          mainLine = RichText(
            text: TextSpan(
              style: _feedBody,
              children: [
                const TextSpan(text: 'Покупка «'),
                TextSpan(
                  text: product,
                  style: _feedBody.copyWith(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: '» $ending'),
              ],
            ),
          );
        }
      } else if (product.isEmpty) {
        mainLine = RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              TextSpan(text: nm, style: _feedName),
              TextSpan(
                text: rejected
                    ? ' — заявку на покупку отклонили'
                    : ' — заявку на покупку одобрили',
              ),
            ],
          ),
        );
      } else {
        mainLine = RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              TextSpan(text: nm, style: _feedName),
              const TextSpan(text: ' — покупку «'),
              TextSpan(
                text: product,
                style: _feedBody.copyWith(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: rejected ? '» отклонили' : '» одобрили'),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mainLine,
          if (priceSuffix != null) ...[
            const SizedBox(height: 4),
            Text(priceSuffix, style: _feedMeta),
          ],
        ],
      );
    }

    String verb;
    String? rewardSuffix;

    if (type == 'quest_submitted') {
      final nm = actorName.trim();
      if (nm.isEmpty) {
        verb = 'Отправлена задача на проверку';
      } else {
        verb =
            '${_isFemale(nm) ? 'Отправила' : 'Отправил'} задачу на проверку';
      }
      if (reward != null && reward.isNotEmpty) rewardSuffix = '(+$reward монет)';
    } else if (type == 'quest_approved') {
      verb = 'Задача принята — награда начислена';
      if (reward != null && reward.isNotEmpty) rewardSuffix = '(+$reward монет)';
    } else if (type == 'quest_rejected') {
      verb = 'Задача отправлена на доработку';
    } else if (type == 'wallet_adjusted') {
      verb = 'Баланс монет изменён';
      if (reward != null && reward.isNotEmpty) {
        rewardSuffix = '($reward монет)';
      }
    } else if (type == 'access_request' || type == 'child_access_requested') {
      verb = 'Новый запрос доступа к семье';
    } else if (type == 'subscription_expiring') {
      verb = 'Подписка скоро закончится — продлите, чтобы не потерять функции';
    } else if (type.startsWith('family_goal')) {
      final nm = actorName.trim();
      verb = nm.isEmpty
          ? 'Добавлена новая семейная цель'
          : '${_isFemale(nm) ? 'Добавила' : 'Добавил'} семейную цель';
      if (reward != null && reward.isNotEmpty) rewardSuffix = '($reward₽)';
    } else {
      final msg =
          (n.payload['message']?.toString() ??
                  n.payload['body']?.toString() ??
                  '')
              .trim();
      if (msg.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actorName.trim().isNotEmpty) Text(actorName.trim(), style: _feedName),
            if (actorName.trim().isNotEmpty) const SizedBox(height: 4),
            Text(msg, style: _feedBody),
          ],
        );
      }
      verb = _friendlyUnknownEventLabel(n.type);
    }

    final questTitleOnly =
        (n.payload['questTitle'] ?? '').toString().trim();
    final titleForQuotes =
        title.isNotEmpty ? title : questTitleOnly;

    if (type == 'quest_submitted' && actorName.trim().isNotEmpty) {
      final nm = actorName.trim();
      final q = questTitleOnly.isEmpty ? title : questTitleOnly;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: _feedBody,
              children: [
                TextSpan(text: nm, style: _feedName),
                TextSpan(text: _isFemale(nm) ? ' — отправила' : ' — отправил'),
                const TextSpan(text: ' задачу на проверку'),
                if (q.isNotEmpty) ...[
                  const TextSpan(text: ' «'),
                  TextSpan(
                    text: q,
                    style: _feedBody.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: '»'),
                ],
              ],
            ),
          ),
          if (rewardSuffix != null) ...[
            const SizedBox(height: 4),
            Text(rewardSuffix, style: _feedMeta),
          ],
        ],
      );
    }

    final showQuotes = titleForQuotes.isNotEmpty &&
        !type.startsWith('shop_purchase_') &&
        (type != 'quest_submitted' || actorName.trim().isEmpty) &&
        type != 'quest_approved' &&
        type != 'subscription_expiring';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              if (actorName.trim().isNotEmpty &&
                  type != 'access_request') ...[
                TextSpan(text: actorName.trim(), style: _feedName),
                const TextSpan(text: ' — '),
              ],
              TextSpan(text: verb),
              if (showQuotes) ...[
                const TextSpan(text: ' «'),
                TextSpan(
                  text: titleForQuotes,
                  style: _feedBody.copyWith(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '»'),
              ],
            ],
          ),
        ),
        if (rewardSuffix != null) ...[
          const SizedBox(height: 4),
          Text(rewardSuffix, style: _feedMeta),
        ],
      ],
    );
  }

  static Widget _reviewAvatar(ParentReviewItem r) {
    final name = r.childName.trim().isEmpty ? 'Ребёнок' : r.childName.trim();
    final fb = name.characters.first.toUpperCase();
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: UserAvatar(
                userKey: 'child:${r.childId}',
                size: 70,
                fallbackText: fb,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.fact_check_outlined,
                  size: 20,
                  color: kChildBrandBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _reviewTextColumn(ParentReviewItem r) {
    final raw = r.childName.trim().isEmpty ? 'Ребёнок' : r.childName.trim();
    final name =
        raw == 'Ребёнок' ? raw : _displayActorName(raw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              TextSpan(text: name, style: _feedName),
              const TextSpan(text: ' — задача «'),
              TextSpan(
                text: r.title,
                style: _feedBody.copyWith(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: '» на проверке'),
            ],
          ),
        ),
        if (r.rewardAmount != null && r.rewardAmount! > 0) ...[
          const SizedBox(height: 4),
          Text('(+${r.rewardAmount} монет)', style: _feedMeta),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty && reviews.isEmpty) {
      return _NeuSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Text(
            'Лента пуста: пока нет проверок и событий',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: kChildInkMuted.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    final rows = <({DateTime t, Widget w})>[];

    final walletByChildId = <String, ParentChildWalletItem>{
      for (final w in wallets) w.childId: w,
    };

    final mergedNotifications = _dedupeNotificationsRecent(notifications);

    for (final n in mergedNotifications) {
      final actorName = _resolvedActorName(n, walletByChildId);
      rows.add((
        t: n.createdAt,
        w: _RecentEventCard(
          avatar: _notificationAvatar(n, actorName, walletByChildId),
          textBlock: _notificationTextColumn(n, actorName),
        ),
      ));
    }
    for (final r in reviews) {
      rows.add((
        t: r.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        w: _RecentEventCard(
          avatar: _reviewAvatar(r),
          textBlock: _reviewTextColumn(r),
        ),
      ));
    }

    rows.sort((a, b) => b.t.compareTo(a.t));

    final shown = rows.take(_kRecentEventsMaxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          shown[i].w,
        ],
      ],
    );
  }
}

class _ChildDetailsPanel extends StatelessWidget {
  const _ChildDetailsPanel({
    required this.wallet,
    required this.activeForChild,
    required this.reviewsForChild,
    required this.onOpenWallet,
    required this.onOpenQuests,
    this.scrollController,
    this.bottomPadding = 20,
  });

  final ParentChildWalletItem wallet;
  final int activeForChild;
  final List<ParentReviewItem> reviewsForChild;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenQuests;
  final ScrollController? scrollController;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final childLabel = wallet.displayName.trim().isEmpty
        ? 'Ребёнок'
        : wallet.displayName.trim();
    final childInitial = childLabel.characters.first.toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        color: kChildSurfaceWhite,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kChildOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              controller: scrollController,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: [
                Row(
                  children: [
                    StatefulBuilder(
                      builder: (ctx, setLocal) => GestureDetector(
                        onTap: () async {
                          final ok = await showAvatarPicker(
                            context: ctx,
                            userKey: 'child:${wallet.childId}',
                            title: 'Аватар: $childLabel',
                          );
                          if (ok) setLocal(() {});
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatar(
                              userKey: 'child:${wallet.childId}',
                              size: 56,
                              fallbackText: childInitial,
                              remoteImageUrl: wallet.avatarImageUrl,
                              remoteDiskCacheKey:
                                  (wallet.avatarObjectKey ?? '')
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : storageObjectDiskCacheKey(
                                          'member-avatars',
                                          wallet.avatarObjectKey!.trim(),
                                        ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: kChildBrandBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            childLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: kChildInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Карточка участника',
                            style: TextStyle(
                              fontSize: 13,
                              color: kChildInkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ChildDetailTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Баланс',
                  value: '${wallet.balance} монет',
                ),
                const SizedBox(height: 10),
                _ChildDetailTile(
                  icon: Icons.assignment_outlined,
                  title: 'Активные задачи',
                  value: '$activeForChild',
                ),
                const SizedBox(height: 10),
                _ChildDetailTile(
                  icon: Icons.fact_check_outlined,
                  title: 'На проверке',
                  value: '${reviewsForChild.length}',
                ),
                const SizedBox(height: 18),
                if (reviewsForChild.isNotEmpty) ...[
                  const Text(
                    'Ожидают проверки',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...reviewsForChild
                      .take(5)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                size: 8,
                                color: kChildAccentOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: kChildInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 18),
                ],
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: onOpenWallet,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Открыть кошелёк'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kChildBrandBlue,
                      foregroundColor: Colors.white,
                      textStyle: kKlanyBrandBluePillTextStyle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onOpenQuests,
                    icon: const Icon(Icons.work_outline),
                    label: const Text('Открыть биржу задач'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kChildBrandBlue,
                      side: const BorderSide(
                        color: kChildBrandBlue,
                        width: 1.4,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildDetailTile extends StatelessWidget {
  const _ChildDetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kChildSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kChildOutline, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kChildBrandBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: kChildBrandBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: kChildInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kChildBrandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNoFamilyCard extends StatelessWidget {
  const _AdminNoFamilyCard({required this.onSignOut});
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
