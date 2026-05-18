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
import '../../quests/quests_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/pages/parent_wallets_page.dart';
import '../../wallet/wallet_repository.dart';
import '../avatar_store.dart';
import '../child_soft_ui.dart';
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ParentFamilySettingsPage()),
    );
  }

  void _openParentShop() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ParentShopPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ParentDashboardView(
        onOpenQuests: () => setState(() => _index = 1),
        onOpenWallet: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ParentWalletsPage()),
          );
        },
      ),
      const ParentQuestsPage(),
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
          resizeToAvoidBottomInset: true,
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
          bottomNavigationBar: _ParentBottomBar(
            homeSelected: _index == 0,
            pendingRequests: _pendingRequestsCount,
            onHome: () => setState(() => _index = 0),
            onOpenShop: _openParentShop,
            onOpenSettings: _openSettings,
          ),
        ),
      ),
    );
  }
}

// ─── Нижняя «капсула» Figma 0-81 ───────────────────────────────────────────

/// Figma iPhone 17 - 45 (`0:1135`): капсула поверх контента.
const double _kParentCapsuleMaxW = 278;
const double _kParentCapsuleH = 76;
const double _kParentCapsuleRadius = 45;
const double _kParentNavGap = 28;
const double _kParentNavSlot = 64;

class _ParentBottomBar extends StatelessWidget {
  const _ParentBottomBar({
    required this.homeSelected,
    required this.pendingRequests,
    required this.onHome,
    required this.onOpenShop,
    required this.onOpenSettings,
  });

  final bool homeSelected;
  final int pendingRequests;
  final VoidCallback onHome;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      height: _kParentCapsuleH + 16 + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kParentCapsuleMaxW),
            child: SizedBox(
              height: _kParentCapsuleH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_kParentCapsuleRadius),
                        border: Border.all(
                          color: const Color(0xFF22459E),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ParentCapsuleNavIcon(
                        asset: 'assets/figma/nav_shop.svg',
                        selected: false,
                        onTap: onOpenShop,
                      ),
                      const SizedBox(width: _kParentNavGap),
                      _ParentCapsuleHomeNav(
                        selected: homeSelected,
                        badgeCount: pendingRequests,
                        onTap: onHome,
                      ),
                      const SizedBox(width: _kParentNavGap),
                      _ParentCapsuleNavIcon(
                        asset: 'assets/figma/nav_tune.svg',
                        selected: false,
                        onTap: onOpenSettings,
                        badgeDot: pendingRequests > 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentCapsuleNavIcon extends StatelessWidget {
  const _ParentCapsuleNavIcon({
    required this.asset,
    required this.selected,
    required this.onTap,
    this.badgeDot = false,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;
  final bool badgeDot;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? Colors.white : kChildInkMuted;
    return Material(
      color: selected ? kChildBrandBlue : Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 6 : 0,
      shadowColor: kChildBrandBlue.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kParentNavSlot,
          height: _kParentNavSlot,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                asset,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              if (badgeDot)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD83A3A),
                      shape: BoxShape.circle,
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

class _ParentCapsuleHomeNav extends StatelessWidget {
  const _ParentCapsuleHomeNav({
    required this.selected,
    required this.onTap,
    required this.badgeCount,
  });

  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kChildBrandBlue : Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 6 : 0,
      shadowColor: kChildBrandBlue.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kParentNavSlot,
          height: _kParentNavSlot,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                selected
                    ? 'assets/figma/nav_home_filled.svg'
                    : 'assets/figma/nav_home_outline.svg',
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  selected ? Colors.white : kChildInkMuted,
                  BlendMode.srcIn,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 12,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD83A3A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
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

// ─── Dashboard: данные + скролл ──────────────────────────────────────────────

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
    required this.onOpenWallet,
  });

  final VoidCallback onOpenQuests;
  final VoidCallback onOpenWallet;

  @override
  ConsumerState<_ParentDashboardView> createState() =>
      _ParentDashboardViewState();
}

class _ParentDashboardViewState extends ConsumerState<_ParentDashboardView> {
  bool _initialLoading = true;
  bool _refreshing = false;
  Object? _loadError;
  ParentFamilyContext? _family;
  List<ParentChildWalletItem> _wallets = const [];
  List<ParentReviewItem> _reviews = const [];
  List<ParentQuestItem> _quests = const [];
  List<InAppNotificationItem> _notifications = const [];
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
          !_sameNotifications(_notifications, data.notifications) ||
          _loadError != null;
      setState(() {
        if (changed) {
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

  Widget _dashboardHeader() {
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
    final bottomPad = 24 + MediaQuery.viewPaddingOf(context).bottom + 8;

    late final List<Widget> listChildren;
    if (_initialLoading && _family == null) {
      listChildren = [
        _dashboardHeader(),
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
        _dashboardHeader(),
        const SizedBox(height: 25),
        if (isAdminNoFamily)
          _AdminNoFamilyCard(
            onSignOut: () => ref.read(authActionsProvider).signOut(),
          )
        else
          _LoadErrorCard(
            title: 'Не удалось загрузить данные',
            error: _loadError ?? 'Семья не найдена',
            onRetry: () => _reload(),
          ),
      ];
    } else {
      final activeQuests = _quests.where((q) => q.status == 'active').toList();
      final totalCoins = _wallets.fold<int>(0, (s, w) => s + w.balance);
      listChildren = [
        _dashboardHeader(),
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
          onQuestsTap: widget.onOpenQuests,
          onGoalTap: widget.onOpenWallet,
        ),
        const _FigmaSectionTitle('Недавние события'),
        const SizedBox(height: 11),
        _MergedActivityFeed(notifications: _notifications, reviews: _reviews),
        const SizedBox(height: 24),
      ];
    }

    return RefreshIndicator(
      onRefresh: () => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
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
    this.footer,
    this.onTap,
    required this.background,
    required this.boxShadows,
  });

  final String title;
  final String value;
  final String? footer;
  final VoidCallback? onTap;
  final Color background;
  final List<BoxShadow> boxShadows;

  @override
  Widget build(BuildContext context) {
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
              Text(
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
    this.onQuestsTap,
    this.onGoalTap,
  });

  final int inProgress;
  final int onReview;
  final int goalTotal;
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
  const _FigmaSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(child: textBlock),
          ],
        ),
      ),
    );
  }
}

class _MergedActivityFeed extends StatelessWidget {
  const _MergedActivityFeed({
    required this.notifications,
    required this.reviews,
  });

  final List<InAppNotificationItem> notifications;
  final List<ParentReviewItem> reviews;

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

  static IconData _iconForNotification(InAppNotificationItem n) {
    final norm = n.type.replaceAll('_', '.');
    if (norm.startsWith('quest.')) {
      return Icons.assignment_turned_in_outlined;
    }
    if (norm.startsWith('shop.')) {
      return Icons.shopping_bag_outlined;
    }
    if (norm.startsWith('wallet.')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (norm.startsWith('access.')) {
      return Icons.person_add_alt_1_outlined;
    }
    if (norm.startsWith('family.')) {
      return Icons.groups_outlined;
    }
    return Icons.notifications_outlined;
  }

  static Widget _notificationAvatar(InAppNotificationItem n, String actorName) {
    final childId =
        n.payload['childId']?.toString() ?? n.payload['actorId']?.toString();
    if (childId != null && childId.isNotEmpty) {
      final fb = actorName.trim().isEmpty
          ? '?'
          : actorName.trim().characters.first.toUpperCase();
      return ClipOval(
        child: UserAvatar(
          userKey: 'child:$childId',
          size: 70,
          fallbackText: fb,
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

  static bool _isFemale(String name) {
    if (name.isEmpty) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('а') || lower.endsWith('я');
  }

  static Widget _notificationTextColumn(
    InAppNotificationItem n,
    String actorName,
  ) {
    final type = n.type.replaceAll('.', '_');
    final title =
        (n.payload['title']?.toString() ??
                n.payload['questTitle']?.toString() ??
                n.payload['productTitle']?.toString() ??
                '')
            .trim();
    final reward =
        n.payload['rewardAmount']?.toString() ??
        n.payload['amount']?.toString() ??
        n.payload['price']?.toString();

    String verb;
    String? rewardSuffix;
    if (type.startsWith('quest_submitted')) {
      verb = 'выполнил${_isFemale(actorName) ? 'а' : ''} задачу';
      if (reward != null) rewardSuffix = '(+$reward монет)';
    } else if (type.startsWith('quest_approved')) {
      verb = 'получил${_isFemale(actorName) ? 'а' : ''} награду';
      if (reward != null) rewardSuffix = '(+$reward монет)';
    } else if (type.startsWith('quest_rejected')) {
      verb = 'задача отклонена';
    } else if (type.startsWith('shop_purchase_requested')) {
      verb = 'запросил${_isFemale(actorName) ? 'а' : ''} покупку';
      if (reward != null) rewardSuffix = '($reward монет)';
    } else if (type.startsWith('shop_purchase_approved')) {
      verb = 'покупка одобрена';
    } else if (type.startsWith('wallet_adjusted')) {
      verb = 'баланс изменён';
      if (reward != null) rewardSuffix = '($reward монет)';
    } else if (type == 'access_request') {
      verb = 'запросил${_isFemale(actorName) ? 'а' : ''} доступ к семье';
    } else if (type.startsWith('family_goal')) {
      verb = 'добавил${_isFemale(actorName) ? 'а' : ''} цель';
      if (reward != null) rewardSuffix = '($reward₽)';
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
            if (actorName.isNotEmpty) Text(actorName, style: _feedName),
            if (actorName.isNotEmpty) const SizedBox(height: 4),
            Text(msg, style: _feedBody),
          ],
        );
      }
      verb = n.type.replaceAll('_', ' ').trim();
      if (verb.isEmpty) verb = 'Событие';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              if (actorName.isNotEmpty) ...[
                TextSpan(text: actorName, style: _feedName),
                const TextSpan(text: ' '),
              ],
              TextSpan(text: verb),
              if (title.isNotEmpty) TextSpan(text: ' «$title»'),
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
    final name = r.childName.trim().isEmpty ? 'Участник' : r.childName.trim();
    final fb = name.characters.first.toUpperCase();
    return ClipOval(
      child: UserAvatar(
        userKey: 'child:${r.childId}',
        size: 70,
        fallbackText: fb,
      ),
    );
  }

  static Widget _reviewTextColumn(ParentReviewItem r) {
    final name = r.childName.trim().isEmpty ? 'Участник' : r.childName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: _feedBody,
            children: [
              TextSpan(text: name, style: _feedName),
              const TextSpan(text: ' — на проверке '),
              TextSpan(text: '«${r.title}»'),
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

    for (final n in notifications.take(24)) {
      final actorName =
          (n.payload['childName']?.toString() ??
                  n.payload['displayName']?.toString() ??
                  n.payload['actorName']?.toString() ??
                  '')
              .trim();
      rows.add((
        t: n.createdAt,
        w: _RecentEventCard(
          avatar: _notificationAvatar(n, actorName),
          textBlock: _notificationTextColumn(n, actorName),
        ),
      ));
    }
    for (final r in reviews.take(16)) {
      rows.add((
        t: r.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        w: _RecentEventCard(
          avatar: _reviewAvatar(r),
          textBlock: _reviewTextColumn(r),
        ),
      ));
    }

    rows.sort((a, b) => b.t.compareTo(a.t));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final e in rows) e.w],
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
                      textStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
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

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({
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
