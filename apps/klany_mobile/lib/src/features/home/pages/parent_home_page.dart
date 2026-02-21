import 'package:flutter/material.dart';

import '../../../core/sdk.dart';
import '../../auth/device_identity.dart';
import 'parent_access_requests_page.dart';
import 'parent_family_settings_page.dart';
import '../../quests/pages/parent_quests_page.dart';
import '../../wallet/pages/parent_wallets_page.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/pages/notifications_page.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _registerDevice();
  }

  Future<void> _registerDevice() async {
    final identity = await DeviceIdentityStore.getOrCreate();
    final userId = Sdk.supabaseOrNull?.auth.currentUser?.id;
    if (userId == null) return;
    await NotificationsRepository().registerDevice(
      userId: userId,
      platform: 'android',
      pseudoPushToken: 'parent-${identity.deviceId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ParentDashboardPage(),
      const ParentAccessRequestsPage(),
      const NotificationsPage(),
      const ParentWalletsPage(),
      const ParentQuestsPage(),
      const ParentShopPage(),
      const ParentFamilySettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.mark_email_unread), label: 'Запросы'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Уведомл.'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Кошельки'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Квесты'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Магазин'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}

class _ParentDashboardPage extends StatelessWidget {
  const _ParentDashboardPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Семья',
      child: Text(
        'Здесь будет: обзор балансов, активных квестов, уведомлений и подписки.',
        style: Theme.of(context).textTheme.bodyMedium,
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
        SliverAppBar(
          pinned: true,
          title: Text(title),
        ),
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

