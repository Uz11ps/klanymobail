import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/sdk.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;
  bool _checkedAdmin = false;

  SupabaseClient? get _client => Sdk.supabaseOrNull;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final client = _client;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      final role = row?['role']?.toString();
      if (role != 'admin') {
        await client.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступа: требуется роль admin')),
        );
        return;
      }
      if (mounted) setState(() => _checkedAdmin = true);
    } catch (e) {
      // If schema isn't applied yet, don't lock the UI; still show dashboard skeleton.
      if (mounted) setState(() => _checkedAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _Section(title: 'Семьи', text: 'CRUD семей + подписки'),
      const _Section(title: 'Пользователи', text: 'Родители/Админы (profiles)'),
      const _Section(title: 'Дети', text: 'Детские аккаунты (phone+password)'),
      const _Section(title: 'Квесты', text: 'Задания, статусы, доказательства'),
      const _Section(title: 'Магазин', text: 'Товары, цены, покупки'),
      const _Section(title: 'Уведомления', text: 'Триггеры/лог'),
      _SettingsSection(onSignOut: () => _client?.auth.signOut()),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  const Text('Admin'),
                  if (!_checkedAdmin)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home), label: Text('Семьи')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Пользователи')),
              NavigationRailDestination(icon: Icon(Icons.child_care), label: Text('Дети')),
              NavigationRailDestination(icon: Icon(Icons.task_alt), label: Text('Квесты')),
              NavigationRailDestination(icon: Icon(Icons.store), label: Text('Магазин')),
              NavigationRailDestination(icon: Icon(Icons.notifications), label: Text('Уведомления')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Настройки')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true, title: Text(title)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Настройки')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти'),
                  onTap: onSignOut,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Дальше добавим страницы таблиц/форм и ограничения по ролям (RLS).',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

