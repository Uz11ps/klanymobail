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
import '../../wallet/pages/child_wallet_page.dart';
import '../../shop/pages/child_shop_page.dart';
import '../../notifications/fcm.dart';
import '../../notifications/notifications_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';

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
      const _ChildDashboardPage(),
      const ChildQuestsPage(),
      const ChildWalletPage(),
      const ChildShopPage(),
      _ChildSettingsPage(onSignOut: () => ref.read(childSessionProvider.notifier).clear()),
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
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
            NavigationDestination(icon: Icon(Icons.task_alt), label: 'Квесты'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Кошелёк'),
            NavigationDestination(icon: Icon(Icons.storefront), label: 'Магазин'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
          ],
        ),
      ),
    );
  }
}

class _ChildDashboardPage extends StatelessWidget {
  const _ChildDashboardPage();

  @override
  Widget build(BuildContext context) {
    return const _ChildDashboardBody();
  }
}

class _ChildDashboardBody extends ConsumerWidget {
  const _ChildDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const _SectionScaffold(title: 'Привет!', child: Text('Сессия ребёнка не найдена'));
    }

    return _SectionScaffold(
      title: (session.childDisplayName).trim().isEmpty ? 'Привет!' : session.childDisplayName,
      child: FutureBuilder<_ChildOverviewData>(
        future: _load(ref, session.childId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Ошибка: ${snapshot.error}'),
              ),
            );
          }
          final data = snapshot.data ?? const _ChildOverviewData(walletBalance: 0, activeAssignments: 0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Баланс'),
                  trailing: Text(
                    data.walletBalance.toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: const Text('Задания'),
                  trailing: Text(
                    data.activeAssignments.toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_ChildOverviewData> _load(WidgetRef ref, String childId) async {
    final wallet = await ref.read(walletRepositoryProvider).getChildWallet(childId);
    final assignments = await ref.read(questsRepositoryProvider).getChildAssignments(childId);
    final active = assignments.where((a) => a.status != 'done' && a.status != 'completed').length;
    return _ChildOverviewData(
      walletBalance: wallet?.balance ?? 0,
      activeAssignments: active,
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

class _ChildSettingsPage extends ConsumerStatefulWidget {
  const _ChildSettingsPage({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<_ChildSettingsPage> createState() => _ChildSettingsPageState();
}

class _ChildSettingsPageState extends ConsumerState<_ChildSettingsPage> {
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

    return _SectionScaffold(
      title: 'Настройки',
      child: FutureBuilder<bool>(
        future: ChildPinStore.hasPin(),
        builder: (context, snapshot) {
          final hasPin = snapshot.data ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                title: Text(hasPin ? 'Сменить PIN-код' : 'Установить PIN-код'),
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
            ],
          );
        },
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true, title: Text(title)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
    );
  }
}

