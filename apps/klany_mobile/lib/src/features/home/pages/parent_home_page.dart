import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_actions.dart';

class ParentHomePage extends ConsumerStatefulWidget {
  const ParentHomePage({super.key});

  @override
  ConsumerState<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends ConsumerState<ParentHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ParentDashboardPage(),
      const _ParentChildrenPage(),
      const _ParentQuestsPage(),
      const _ParentShopPage(),
      _ParentSettingsPage(onSignOut: () => ref.read(authActionsProvider).signOut()),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Дети'),
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

class _ParentChildrenPage extends StatelessWidget {
  const _ParentChildrenPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Дети',
      actions: [
        IconButton(
          tooltip: 'Добавить',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Дальше добавим форму создания ребёнка + пароль')),
            );
          },
          icon: const Icon(Icons.add),
        ),
      ],
      child: Text(
        'Список детей семьи, привязка телефона, активация/блокировка.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ParentQuestsPage extends StatelessWidget {
  const _ParentQuestsPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Квесты',
      actions: [
        IconButton(
          tooltip: 'Создать',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Дальше добавим создание/назначение квеста')),
            );
          },
          icon: const Icon(Icons.add_task),
        ),
      ],
      child: Text(
        'Список квестов, статусы, проверка (фото/чек).',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ParentShopPage extends StatelessWidget {
  const _ParentShopPage();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Магазин',
      child: Text(
        'Товары/награды, цены во внутренней валюте, выдача/возвраты.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ParentSettingsPage extends StatelessWidget {
  const _ParentSettingsPage({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Настройки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Профиль'),
            subtitle: const Text('Роль, семья, подписка'),
            onTap: () {},
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
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
          actions: actions,
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

