import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_actions.dart';

class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ChildDashboardPage(),
      const _ChildQuestsPage(),
      const _ChildWalletPage(),
      const _ChildShopPage(),
      _ChildSettingsPage(onSignOut: () => ref.read(authActionsProvider).signOut()),
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

class _ChildQuestsPage extends StatelessWidget {
  const _ChildQuestsPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Квесты',
      child: Text(
        'Список назначенных заданий, отметка выполнения и фото-подтверждение.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ChildWalletPage extends StatelessWidget {
  const _ChildWalletPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Кошелёк',
      child: Text(
        'Баланс внутренней валюты, история начислений/списаний.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ChildShopPage extends StatelessWidget {
  const _ChildShopPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Магазин',
      child: Text(
        'Доступные товары/награды, оформление запроса на покупку.',
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
            subtitle: Text('Ребёнок / телефон'),
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

