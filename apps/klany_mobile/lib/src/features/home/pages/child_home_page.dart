import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../auth/child_pin_store.dart';
import '../../auth/device_identity.dart';
import '../../quests/pages/child_quests_page.dart';
import '../../quests/quests_repository.dart';
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
        .where((a) => a.status != 'done' && a.status != 'completed')
        .length;
    return _ChildOverviewData(
      walletBalance: wallet?.balance ?? 0,
      activeAssignments: active,
    );
  }

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    setState(() => _future = _load(session.childId));
    await _future;
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ChildHeroCard(
                      initial: displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
                      level: 1,
                      name: displayName,
                      subtitle: 'Твоя детская панель в стиле клана',
                      balance: balance,
                      personal: 0,
                      exchange: 0,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Инфо-панель',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ChildStatCard(
                            icon: Icons.assignment_turned_in,
                            accentColor: kChildAccentGreen,
                            title: 'МОИ ЗАДАЧИ',
                            value: active.toString(),
                            caption: 'личных задач в работе',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ChildStatCard(
                            icon: Icons.check_circle,
                            accentColor: kChildAccentGreen,
                            title: 'БИРЖА',
                            value: '0',
                            caption: 'можно взять с биржи',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChildSoftCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: kChildAccentOrange.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.flag_rounded,
                              color: kChildAccentOrange,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ОБЩАЯ ЦЕЛЬ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: kChildInk,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Общая цель',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: kChildAccentOrange,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Скоро родитель задаст общую цель семьи.',
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
  });

  final int walletBalance;
  final int activeAssignments;
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
                          value: '$balance ₽',
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
  const _ChildHeroMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
