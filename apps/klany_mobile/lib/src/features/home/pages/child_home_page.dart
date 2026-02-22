import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../auth/device_identity.dart';
import '../../quests/pages/child_quests_page.dart';
import '../../wallet/pages/child_wallet_page.dart';
import '../../shop/pages/child_shop_page.dart';
import '../../notifications/notifications_repository.dart';

class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  int _index = 0;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _registerDevice();
    _sessionTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      await ref.read(childSessionProvider.notifier).validateStillActive();
    });
  }

  Future<void> _registerDevice() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final identity = await DeviceIdentityStore.getOrCreate();
    await ref.read(notificationsRepositoryProvider).registerDevice(
          platform: 'android',
          pseudoPushToken: 'child-${identity.deviceId}',
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

    return Scaffold(
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
    );
  }
}

class _ChildDashboardPage extends StatelessWidget {
  const _ChildDashboardPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Привет!',
      child: Text(
        'Здесь будет: прогресс, баланс, ближайшие задания, уведомления.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ChildSettingsPage extends StatelessWidget {
  const _ChildSettingsPage({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Настройки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Аккаунт'),
            subtitle: Text('Ребёнок / доступ по подтверждению'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: onSignOut,
          ),
        ],
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

