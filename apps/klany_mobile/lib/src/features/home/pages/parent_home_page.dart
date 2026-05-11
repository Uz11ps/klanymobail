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
import '../avatar_store.dart';
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ParentFamilySettingsPage(),
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

// APK-exact pill: BoxDecoration with bg/border/shadow + Badge icon + label in Row.

// APK-exact bottom bar: neuCard(r=30) wrapping 2 pills + Material(CircleBorder) settings.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // White rounded bar background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left: Биржа
                  _BottomNavRoundBtn(
                    icon: Icons.work_outline,
                    selected: currentIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  // Center: Главная (big blue circle)
                  _BottomNavCenterBtn(
                    selected: currentIndex == 0,
                    onTap: () => onSelected(0),
                    badgeCount: pendingRequests,
                  ),
                  // Right: Настройки
                  _BottomNavRoundBtn(
                    icon: Icons.settings_outlined,
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
    );
  }
}

class _BottomNavRoundBtn extends StatelessWidget {
  const _BottomNavRoundBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeDot = false,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool badgeDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kChildBrandBlue.withValues(alpha: 0.12) : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? kChildBrandBlue : kChildInkMuted,
              ),
              if (badgeDot)
                Positioned(
                  top: 12,
                  right: 12,
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

class _BottomNavCenterBtn extends StatelessWidget {
  const _BottomNavCenterBtn({
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
      color: kChildBrandBlue,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 6 : 2,
      shadowColor: kChildBrandBlue.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.home_filled,
                size: 30,
                color: Colors.white,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

// ─── APK-exact dashboard widgets ──────────────────────────────────────────────

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ClanCapitalUi.neuCard(radius: 26, color: color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}

class _InfoPanelCard extends StatelessWidget {
  const _InfoPanelCard({
    required this.title,
    required this.value,
    required this.emoji,
    this.unit,
    this.footer,
    this.progress,
    this.progressCaption,
    this.onTap,
    this.bg,
  });
  final String title;
  final String value;
  final String emoji;
  final String? unit;
  final String? footer;
  final double? progress;
  final String? progressCaption;
  final VoidCallback? onTap;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            color: bg ?? Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
                  height: 1.15,
                ),
                maxLines: 2,
              ),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: kChildInk,
                  height: 1.0,
                ),
              ),
              SizedBox(
                height: 16,
                child: footer != null
                    ? Text(
                        footer!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kChildInkMuted.withValues(alpha: 0.85),
                          letterSpacing: 0.2,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardInfoPanelGrid extends StatelessWidget {
  const _DashboardInfoPanelGrid({
    required this.inProgress,
    required this.onReview,
    required this.goalCurrent,
    required this.goalTarget,
    this.onQuestsTap,
    this.onGoalTap,
  });
  final int inProgress;
  final int onReview;
  final int goalCurrent;
  final int goalTarget;
  final VoidCallback? onQuestsTap;
  final VoidCallback? onGoalTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
          Expanded(
            child: _InfoPanelCard(
              title: 'В работе',
              emoji: '🧰',
              value: '$inProgress',
              footer: 'КЛАН / ВСЕ',
              onTap: onQuestsTap,
              bg: kBrandSky,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoPanelCard(
              title: 'На проверке',
              emoji: '🔎',
              value: '$onReview',
              bg: kBrandSunny,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoPanelCard(
              title: 'Общая цель',
              emoji: '🔐',
              value: '$goalCurrent',
              footer: 'Накопления',
              onTap: onGoalTap,
              bg: kBrandMint,
            ),
          ),
        ],
    );
  }
}

class _DashboardSelectorStrip extends StatefulWidget {
  const _DashboardSelectorStrip({
    required this.wallets,
    required this.parents,
    required this.onWalletTap,
  });
  final List<ParentChildWalletItem> wallets;
  final List<ParentMemberItem> parents;
  final ValueChanged<ParentChildWalletItem> onWalletTap;

  @override
  State<_DashboardSelectorStrip> createState() =>
      _DashboardSelectorStripState();
}

class _DashboardSelectorStripState extends State<_DashboardSelectorStrip> {
  int _selected = -1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundMemberChip(
              label: 'Все',
              icon: Icons.groups_rounded,
              selected: _selected == -1,
              onTap: () => setState(() => _selected = -1),
            ),
            // Родители
            ...widget.parents.map((p) {
              final name = p.displayName.trim().isEmpty
                  ? 'Родитель'
                  : p.displayName.trim();
              final initial = name.characters.first.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _RoundMemberChip(
                  label: name,
                  initial: initial,
                  selected: false,
                  isParent: true,
                  onTap: () {},
                ),
              );
            }),
            // Дети
            ...widget.wallets.asMap().entries.map((e) {
              final name = e.value.displayName.trim().isEmpty
                  ? '—'
                  : e.value.displayName.trim();
              final initial = name.characters.first.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _RoundMemberChip(
                  label: name,
                  initial: initial,
                  selected: _selected == e.key,
                  userKey: 'child:${e.value.childId}',
                  onTap: () {
                    setState(() => _selected = e.key);
                    widget.onWalletTap(e.value);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RoundMemberChip extends StatelessWidget {
  const _RoundMemberChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.initial,
    this.isParent = false,
    this.userKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? initial;
  final bool isParent;
  final String? userKey;

  static const _palette = <(Color, Color)>[
    (kBrandMint, Color(0xFF2D6B28)),
    (kBrandSky, Color(0xFF1E4F8E)),
    (kBrandLavender, Color(0xFF4F3FAA)),
    (kBrandSunny, Color(0xFF96701A)),
    (kBrandPeach, Color(0xFF8E4424)),
    (kBrandRose, Color(0xFF9E2A4A)),
  ];

  static String _avatarAssetForName(String name) {
    final idx = (name.hashCode.abs() % 9) + 1;
    return 'assets/figma/avatar_$idx.png';
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (selected) {
      bg = kChildBrandBlue;
      fg = Colors.white;
    } else if (isParent) {
      bg = const Color(0xFFFFF1D6);
      fg = const Color(0xFFB57A00);
    } else if (icon != null) {
      // "All" pill — keep it sky-blue
      bg = const Color(0xFFE3ECF8);
      fg = kChildBrandBlue;
    } else {
      // Pick a stable color from palette based on the label
      final pair = _palette[label.hashCode.abs() % _palette.length];
      bg = pair.$1;
      fg = pair.$2;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 96,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: selected
              ? Border.all(color: kChildBrandBlue, width: 2)
              : Border.all(color: const Color(0xFFE7ECF3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, color: fg, size: 28)
                  : (userKey != null)
                      ? UserAvatar(
                          userKey: userKey!,
                          size: 64,
                          fallbackText: initial,
                        )
                      : Text(
                          initial ?? '?',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 84,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kChildInk,
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
  List<ParentMemberItem> _parents = const <ParentMemberItem>[];
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

  Future<void> _showChildDetails(ParentChildWalletItem wallet) async {
    final activeForChild = _quests
        .where(
          (q) =>
              q.status == 'active' &&
              (q.distributionType == 'exchange' ||
                  q.childIds.contains(wallet.childId)),
        )
        .length;
    final reviewsForChild =
        _reviews.where((r) => r.childId == wallet.childId).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: kChildSurfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kChildOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  StatefulBuilder(
                    builder: (ctx, setLocal) => GestureDetector(
                      onTap: () async {
                        final ok = await showAvatarPicker(
                          context: ctx,
                          userKey: 'child:${wallet.childId}',
                          title: 'Аватар: ${wallet.displayName}',
                        );
                        if (ok) setLocal(() {});
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(
                            userKey: 'child:${wallet.childId}',
                            size: 56,
                            fallbackText: wallet.displayName.trim().isEmpty
                                ? '?'
                                : wallet.displayName.characters.first
                                    .toUpperCase(),
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
                          wallet.displayName.trim().isEmpty
                              ? 'Без имени'
                              : wallet.displayName,
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
              _ChildDetailRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Баланс',
                value: '${wallet.balance} монет',
              ),
              const SizedBox(height: 10),
              _ChildDetailRow(
                icon: Icons.assignment_outlined,
                title: 'Активные задачи',
                value: '$activeForChild',
              ),
              const SizedBox(height: 10),
              _ChildDetailRow(
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
                ...reviewsForChild.take(5).map(
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
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onOpenWallet();
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Открыть кошелёк'),
                style: FilledButton.styleFrom(
                  backgroundColor: kChildBrandBlue,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onOpenQuests();
                },
                icon: const Icon(Icons.work_outline),
                label: const Text('Открыть биржу задач'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kChildBrandBlue,
                  side: const BorderSide(color: kChildBrandBlue, width: 1.4),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clanName = (_family?.clanName ?? '').trim().isEmpty
        ? 'Семья'
        : _family!.clanName!.trim();
    const parentName = 'Глава Клана';

    if (_initialLoading && _family == null) {
      return _buildScaffold(
        title: 'Главное: клан',
        parentName: parentName,
        child: const Column(
          children: [
            _SkeletonCard(height: 80),
            SizedBox(height: 10),
            _SkeletonCard(height: 80),
            SizedBox(height: 10),
            _SkeletonCard(height: 120),
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
        title: 'Главное: клан',
        parentName: parentName,
        child: _ErrorCard(
          title: 'Не удалось загрузить данные',
          error: _loadError ?? 'Семья не найдена',
          onRetry: () => _reload(),
        ),
      );
    }

    final family = _family!;
    final activeQuests = _quests
        .where((q) => q.status == 'active')
        .toList();
    final total = _wallets.fold<int>(0, (sum, w) => sum + w.balance);
    final title =
        clanName.isEmpty ? 'Главное: клан' : 'Главное: $clanName';

    return _buildScaffold(
      title: title,
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
          // APK: selector first.
          _DashboardSelectorStrip(
            wallets: _wallets,
            parents: _parents,
            onWalletTap: _showChildDetails,
          ),
          const SizedBox(height: 18),
          // APK: "Инфо-панель" section title with divider.
          const _SectionTitleWithDivider('Инфо-панель'),
          _DashboardInfoPanelGrid(
            inProgress: activeQuests.length,
            onReview: _reviews.length,
            goalCurrent: total,
            goalTarget: family.goalAmount,
            onQuestsTap: widget.onOpenQuests,
            onGoalTap: widget.onOpenWallet,
          ),
          const SizedBox(height: 14),
          // APK: feed — pending reviews + recent notifications.
          if (_reviews.isEmpty && _notifications.isEmpty)
            _SoftCard(
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
            )
          else ...[
            const SizedBox(height: 4),
            const _SectionTitleWithDivider('Недавние события'),
            if (_notifications.isNotEmpty)
              _NotificationsFeedCard(items: _notifications)
            else
              _SoftCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  child: Text(
                    'Лента пуста',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: kChildInkMuted.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
          ],
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
    final body = ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Figma: big CLAN CAPITAL title + round white refresh button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'CLAN CAPITAL',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: kChildBrandBlue,
                  letterSpacing: 0.5,
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
                onTap: widget.onOpenNotifications,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: kChildInk,
                        size: 22,
                      ),
                      if (_notifications.any((n) => n.status != 'read'))
                        Positioned(
                          top: 10,
                          right: 11,
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
            ),
            const SizedBox(width: 10),
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.14),
              child: InkWell(
                onTap: () => _reload(),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: kChildInk,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );

    return Container(
      color: kBgCloud,
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
          !_sameParents(_parents, data.parents) ||
          _loadError != null;
      setState(() {
        if (hasChanged) {
          _family = data.family;
          _wallets = data.wallets;
          _reviews = data.reviews;
          _quests = data.quests;
          _notifications = data.notifications;
          _parents = data.parents;
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
        parents: <ParentMemberItem>[],
      );
    }

    final results = await Future.wait<dynamic>([
      ref.read(questsRepositoryProvider).getSubmittedForReview(family.familyId),
      ref.read(questsRepositoryProvider).getParentQuests(family.familyId),
      ref.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
      ref
          .read(notificationsRepositoryProvider)
          .listFamilyNotifications(family.familyId),
      ref.read(parentAccessRepositoryProvider).getParentMembers(family.familyId),
    ]);

    return _ParentDashboardSnapshot(
      family: family,
      reviews: results[0] as List<ParentReviewItem>,
      quests: results[1] as List<ParentQuestItem>,
      wallets: results[2] as List<ParentChildWalletItem>,
      notifications: results[3] as List<InAppNotificationItem>,
      parents: results[4] as List<ParentMemberItem>,
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

  bool _sameParents(List<ParentMemberItem> a, List<ParentMemberItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.userId != y.userId ||
          x.displayName != y.displayName ||
          x.role != y.role) { return false; }
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

// ─── Child details bottom sheet helpers ──────────────────────────────────────

class _ChildDetailRow extends StatelessWidget {
  const _ChildDetailRow({
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

// ─── Notifications feed ──────────────────────────────────────────────────────

class _NotificationsFeedCard extends StatelessWidget {
  const _NotificationsFeedCard({required this.items});
  final List<InAppNotificationItem> items;

  String _titleFor(InAppNotificationItem n) {
    final t = n.payload['title']?.toString();
    if (t != null && t.isNotEmpty) return t;
    final norm = n.type.replaceAll('_', '.');
    switch (norm) {
      case 'quest.submitted':
        return 'Задание отправлено на проверку';
      case 'quest.approved':
      case 'quest.completed':
        return 'Задание подтверждено';
      case 'quest.rejected':
        return 'Задание отклонено';
      case 'quest.taken':
        return 'Задание взято с биржи';
      case 'quest.created':
        return 'Создано новое задание';
      case 'shop.purchase.requested':
        return 'Заявка на покупку';
      case 'shop.purchase.approved':
        return 'Покупка одобрена';
      case 'shop.purchase.rejected':
        return 'Покупка отклонена';
      case 'shop.product.created':
        return 'Добавлен новый товар';
      case 'wallet.adjusted':
      case 'wallet.adjustment':
        return 'Корректировка баланса';
      case 'access.requested':
      case 'access.request':
        return 'Запрос на доступ';
      case 'access.approved':
        return 'Доступ одобрен';
      case 'access.rejected':
        return 'Доступ отклонён';
      case 'family.member.added':
        return 'Новый участник в клане';
      case 'family.goal.updated':
        return 'Обновлена цель семьи';
      default:
        return n.type.isEmpty ? 'Событие' : 'Событие';
    }
  }

  String _subtitleFor(InAppNotificationItem n) {
    final s = n.payload['message']?.toString() ??
        n.payload['subtitle']?.toString() ??
        n.payload['body']?.toString();
    if (s != null && s.isNotEmpty) return s;
    final who = n.payload['childName']?.toString() ??
        n.payload['actorName']?.toString();
    return who ?? '';
  }

  IconData _iconFor(InAppNotificationItem n) {
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final list = items.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: list.map((n) {
        final childId =
            n.payload['childId']?.toString() ?? n.payload['actorId']?.toString();
        final actorName = (n.payload['childName']?.toString() ??
                n.payload['displayName']?.toString() ??
                n.payload['actorName']?.toString() ??
                '')
            .trim();
        final richText = _buildRichEvent(n, actorName);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7ECF3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (childId != null && childId.isNotEmpty)
                  ClipOval(
                    child: UserAvatar(userKey: 'child:$childId', size: 48),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kChildBrandBlue.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _iconFor(n),
                      size: 22,
                      color: kChildBrandBlue,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(child: richText),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRichEvent(InAppNotificationItem n, String actorName) {
    final type = n.type;
    final title = (n.payload['title']?.toString() ??
            n.payload['questTitle']?.toString() ??
            n.payload['productTitle']?.toString() ??
            '')
        .trim();
    final reward = n.payload['rewardAmount']?.toString() ??
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
      verb = 'обновление';
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: kChildInk,
          height: 1.35,
        ),
        children: [
          if (actorName.isNotEmpty) ...[
            TextSpan(
              text: actorName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const TextSpan(text: ' '),
          ],
          TextSpan(text: verb),
          if (title.isNotEmpty) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: '«$title»',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          if (rewardSuffix != null) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: rewardSuffix,
              style: TextStyle(color: kChildInkMuted.withValues(alpha: 0.85)),
            ),
          ],
        ],
      ),
    );
  }

  bool _isFemale(String name) {
    if (name.isEmpty) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('а') || lower.endsWith('я');
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
    required this.parents,
  });

  final ParentFamilyContext? family;
  final List<ParentChildWalletItem> wallets;
  final List<ParentReviewItem> reviews;
  final List<ParentQuestItem> quests;
  final List<InAppNotificationItem> notifications;
  final List<ParentMemberItem> parents;
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

/// Section title with horizontal divider line (Figma style).
class _SectionTitleWithDivider extends StatelessWidget {
  const _SectionTitleWithDivider(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kChildInk,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: kChildOutline),
        ],
      ),
    );
  }
}
