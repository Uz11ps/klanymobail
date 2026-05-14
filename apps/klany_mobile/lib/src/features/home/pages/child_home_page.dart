import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../auth/child_pin_store.dart';
import '../avatar_store.dart';
import '../../auth/device_identity.dart';
import '../../quests/pages/child_quests_page.dart';
import '../../quests/quests_repository.dart';
import '../../wallet/pages/child_wallet_page.dart';
import '../../wallet/wallet_repository.dart';
import '../../shop/pages/child_shop_page.dart';
import '../../notifications/fcm.dart';
import '../../notifications/notifications_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';
import '../child_soft_ui.dart';

class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  int _index = 0;
  Timer? _sessionTimer;
  int _registerAttempts = 0;

  @override
  void initState() {
    super.initState();
    _registerDevice();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    _sessionTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      await ref.read(childSessionProvider.notifier).validateStillActive();
    });
  }

  Future<void> _maybeShowTour() async {
    final seen = await OnboardingStore.isChildTourSeen();
    if (seen || !mounted) return;
    await showOnboardingTourDialog(
      context: context,
      title: childTourTitle,
      steps: childTourSteps,
    );
    await OnboardingStore.setChildTourSeen();
  }

  Future<void> _registerDevice() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final identity = await DeviceIdentityStore.getOrCreate();
    final pushToken = await Fcm.getToken();
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.windows => 'windows',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.linux => 'linux',
            TargetPlatform.fuchsia => 'fuchsia',
          };
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
    await ref.read(notificationsRepositoryProvider).registerDevice(
      platform: platform,
      pseudoPushToken: (pushToken != null && pushToken.isNotEmpty)
          ? pushToken
          : 'child-${identity.deviceId}',
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ChildDashboardBody(),
      const ChildQuestsPage(),
      const ChildShopPage(),
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
        bottomNavigationBar: ChildBottomClanBar(
          currentIndex: _index,
          onSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _ChildDashboardBody extends ConsumerStatefulWidget {
  const _ChildDashboardBody();

  @override
  ConsumerState<_ChildDashboardBody> createState() =>
      _ChildDashboardBodyState();
}

class _ChildDashboardBodyState extends ConsumerState<_ChildDashboardBody> {
  Future<_ChildOverviewData>? _future;

  Future<_ChildOverviewData> _load(String childId) async {
    final wallet = await ref.read(walletRepositoryProvider).getChildWallet(childId);
    final assignments = await ref.read(questsRepositoryProvider).getChildAssignments(childId);
    final active = assignments
        .where((a) => a.distributionType != 'exchange' &&
            a.status != 'done' &&
            a.status != 'completed')
        .length;
    final exchange = assignments
        .where((a) => a.distributionType == 'exchange')
        .length;
    final completed = assignments
        .where((a) => a.status == 'completed' || a.status == 'done')
        .length;
    final balance = wallet?.balance ?? 0;
    const goal = 10000;
    return _ChildOverviewData(
      walletBalance: balance,
      activeAssignments: active,
      exchangeCount: exchange,
      completedCount: completed,
      goalCurrent: balance,
      goalTarget: goal,
      goalProgress: balance / goal,
    );
  }

  String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'задачи';
    return 'задач';
  }

  Future<void> _showReverseTaskDialog(BuildContext context) async {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Обратная задача',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Поставь спец-цель с родителем. Когда соберёшь нужную сумму — родитель её исполнит.',
              style: TextStyle(fontSize: 13, color: kChildInkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название цели',
                hintText: 'Например: Подарок маме',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сколько монет нужно',
                hintText: '500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kBrandMint,
              foregroundColor: const Color(0xFF1F4F1B),
              elevation: 4,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final title = titleCtl.text.trim();
    final amount = int.tryParse(amountCtl.text.trim()) ?? 0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название и сумму'),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(questsRepositoryProvider).createReverseQuest(
            title: title,
            rewardAmount: amount,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Цель «$title» на $amount монет отправлена родителю'),
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final f = _load(session.childId);
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: Text('Сессия ребёнка не найдена'));
    }
    _future ??= _load(session.childId);
    final displayName = session.childDisplayName.trim().isEmpty
        ? 'Привет!'
        : session.childDisplayName;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CLAN CAPITAL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: kChildBrandBlue,
                          letterSpacing: 1.6,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Главное: $displayName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, color: kChildInk),
                ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: kChildSurfaceWhite,
                      builder: (ctx) => _ChildSettingsSheet(
                        onSignOut: () => ref
                            .read(childSessionProvider.notifier)
                            .clear(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts, color: kChildInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<_ChildOverviewData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final balance = data?.walletBalance ?? 0;
              final active = data?.activeAssignments ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChildSoftCard(
                      color: Colors.white,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final changed = await showAvatarPicker(
                                context: context,
                                userKey: 'child:${session.childId}',
                                title: 'Выбрать аватар',
                              );
                              if (changed && mounted) setState(() {});
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                UserAvatar(
                                  userKey: 'child:${session.childId}',
                                  size: 64,
                                  fallbackText: displayName.isEmpty
                                      ? '?'
                                      : displayName.characters.first
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: kChildInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${data?.completedCount ?? 0} ${_taskWord(data?.completedCount ?? 0)} выполнено',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kChildInkMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ChildWalletPage(),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF2F8),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CoinStackIcon(size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatNumber(balance),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: kChildBrandBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: kChildOutline),
                  ),
                  const SizedBox(height: 18),
                  // Two square buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ChildSquareTile(
                            label: 'Мои задачи',
                            value: active.toString(),
                            color: kBrandMint,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ChildSquareTile(
                            label: 'Биржа',
                            value: (data?.exchangeCount ?? 0).toString(),
                            color: kBrandLavender,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Goal progress
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChildSoftCard(
                      color: kBrandSunny,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Text(
                            'Текущая цель',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kChildInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              height: 16,
                              child: LinearProgressIndicator(
                                value:
                                    (data?.goalProgress ?? 0).clamp(0.0, 1.0),
                                backgroundColor: Colors.white,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  kChildBrandBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${data?.goalCurrent ?? balance} / ${data?.goalTarget ?? 10000} монет',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kChildInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Reverse task card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChildSoftCard(
                      color: Colors.white,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Обратная задача',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kChildInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Поставь одну спец-цель с родителем. Собранное идет в цель.',
                            style: TextStyle(
                              fontSize: 13,
                              color: kChildInkMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => _showReverseTaskDialog(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: kBrandMint,
                              foregroundColor: const Color(0xFF1F4F1B),
                              elevation: 4,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Создать',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChildOverviewData {
  const _ChildOverviewData({
    required this.walletBalance,
    required this.activeAssignments,
    this.exchangeCount = 0,
    this.completedCount = 0,
    this.goalCurrent = 0,
    this.goalTarget = 10000,
    this.goalProgress = 0.0,
  });

  final int walletBalance;
  final int activeAssignments;
  final int exchangeCount;
  final int completedCount;
  final int goalCurrent;
  final int goalTarget;
  final double goalProgress;
}

class _ChildSquareTile extends StatelessWidget {
  const _ChildSquareTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.05,
      child: ChildSoftCard(
        color: color,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kChildInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: kChildInk,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildHeroCard extends StatelessWidget {
  const _ChildHeroCard({
    required this.initial,
    required this.level,
    required this.name,
    required this.subtitle,
    required this.balance,
    required this.personal,
    required this.exchange,
  });

  final String initial;
  final int level;
  final String name;
  final String subtitle;
  final int balance;
  final int personal;
  final int exchange;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kChildBrandBlue, Color(0xFF5A8EFF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x471E2D52),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // decorative orbit rings (top-right)
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
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$level',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
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
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ChildHeroMetric(
                          title: 'БАЛАНС',
                          value: '$balance 🪙',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChildWalletPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChildHeroMetric(
                          title: 'ЛИЧНО',
                          value: personal.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChildHeroMetric(
                          title: 'БИРЖА',
                          value: exchange.toString(),
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

class _ChildHeroMetric extends StatelessWidget {
  const _ChildHeroMetric({
    required this.title,
    required this.value,
    this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _ChildStatCard extends StatelessWidget {
  const _ChildStatCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kChildInk,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 12,
              color: kChildInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildSettingsSheet extends ConsumerStatefulWidget {
  const _ChildSettingsSheet({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<_ChildSettingsSheet> createState() =>
      _ChildSettingsSheetState();
}

class _ChildSettingsSheetState extends ConsumerState<_ChildSettingsSheet> {
  Future<String?>? _authCodeFuture;
  String? _authCodeToken;

  Future<String?> _loadAuthCode(String accessToken) {
    return ref
        .read(passwordlessChildRepositoryProvider)
        .getMyAuthCode(accessToken: accessToken);
  }

  Future<void> _showTourAgain() async {
    await showOnboardingTourDialog(
      context: context,
      title: childTourTitle,
      steps: childTourSteps,
    );
    await OnboardingStore.setChildTourSeen();
  }

  Future<void> _setOrChangePin() async {
    final pinCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN-код ребёнка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Новый PIN (6 цифр)',
                counterText: '',
              ),
            ),
            TextField(
              controller: confirmCtl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Повторите PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final pin = pinCtl.text.trim();
    final confirm = confirmCtl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN должен состоять из 6 цифр')),
      );
      return;
    }
    if (pin != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN-коды не совпадают')),
      );
      return;
    }

    await ChildPinStore.setPin(pin);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN сохранён')),
    );
  }

  Future<void> _clearPin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс PIN'),
        content: const Text('Удалить PIN-код для быстрого входа ребёнка?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ChildPinStore.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN удалён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isNotEmpty && _authCodeToken != accessToken) {
      _authCodeToken = accessToken;
      _authCodeFuture = _loadAuthCode(accessToken);
    }

    return FutureBuilder<bool>(
      future: ChildPinStore.hasPin(),
      builder: (context, snapshot) {
        final hasPin = snapshot.data ?? false;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Аккаунт'),
                subtitle: Text('Ребёнок / доступ по подтверждению'),
              ),
              FutureBuilder<String?>(
                future: _authCodeFuture,
                builder: (context, codeSnapshot) {
                  final code = codeSnapshot.data ?? '------';
                  return ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('Код входа ребёнка'),
                    subtitle: Text(
                      '$code\nИспользуйте этот код для входа с другого телефона.',
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pin),
                title:
                    Text(hasPin ? 'Сменить PIN-код' : 'Установить PIN-код'),
                subtitle: const Text('6 цифр для быстрого входа ребёнка'),
                onTap: _setOrChangePin,
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Сбросить PIN-код'),
                  onTap: _clearPin,
                ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Показать обучение снова'),
                onTap: _showTourAgain,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Выйти'),
                onTap: widget.onSignOut,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
