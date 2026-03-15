import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/sdk.dart';
import '../../../core/csv_export.dart';
import '../../auth/auth_providers.dart';
import '../admin_repository.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _index = 0;
  bool _checkedAdmin = false;
  bool _checking = false;

  SupabaseClient? get _client => Sdk.supabaseOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  Future<void> _checkAdmin() async {
    if (_checking) return;
    _checking = true;

    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) setState(() => _checkedAdmin = true);
      return;
    }

    try {
      final row = await client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      final role = row?['role']?.toString();
      if (role != 'admin' && role != 'parent') {
        await client.auth.signOut();
        if (!mounted) return;
        setState(() => _checkedAdmin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет доступа: требуется роль admin или parent'),
          ),
        );
        return;
      }
      if (mounted) setState(() => _checkedAdmin = true);
    } catch (_) {
      if (mounted) setState(() => _checkedAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final repo = AdminRepository(client);
    final isCompact = MediaQuery.sizeOf(context).width < 980;
    final session = ref.watch(authSessionProvider).asData?.value;
    final role = (session?.role ?? 'admin').trim();
    final isParentMode = role == 'parent';
    final accessToken = session?.accessToken ?? '';
    final userId = session?.userId ?? '';

    final pages = isParentMode
        ? <Widget>[
            _OverviewPage(repo: repo, accessToken: accessToken, role: role),
            _AccessRequestsQueuePage(
              repo: repo,
              accessToken: accessToken,
              role: role,
            ),
            _ParentChildrenPage(
              repo: repo,
              accessToken: accessToken,
              role: role,
            ),
            _ParentProductsPage(
              repo: repo,
              accessToken: accessToken,
              role: role,
            ),
            _ParentQuestsPage(repo: repo, accessToken: accessToken, role: role),
            _SettingsSection(
              repo: repo,
              accessToken: accessToken,
              role: role,
              onSignOut: () async {
                await client?.auth.signOut();
                await clearAdminSession(ref);
              },
            ),
          ]
        : <Widget>[
            _OverviewPage(repo: repo, accessToken: accessToken, role: role),
            _AccessRequestsQueuePage(
              repo: repo,
              accessToken: accessToken,
              role: role,
            ),
            _PurchasesQueuePage(repo: repo),
            _QuestReviewQueuePage(repo: repo),
            _PromoAndSubsPage(repo: repo),
            _PaymentsAndWebhooksPage(repo: repo),
            _AnalyticsPage(repo: repo),
            _OperationsPage(repo: repo, accessToken: accessToken, role: role),
            _AdminAccountsPage(
              repo: repo,
              accessToken: accessToken,
              currentUserId: userId,
            ),
            _SettingsSection(
              repo: repo,
              accessToken: accessToken,
              role: role,
              onSignOut: () async {
                await client?.auth.signOut();
                await clearAdminSession(ref);
              },
            ),
          ];

    if (isCompact) {
      final labels = isParentMode
          ? const <String>[
              'Дашборд',
              'Запросы',
              'Дети',
              'Товары',
              'Квесты',
              'Настройки',
            ]
          : const <String>[
              'Дашборд',
              'Запросы',
              'Покупки',
              'Квесты',
              'Промо/Подписки',
              'Платежи',
              'Аналитика',
              'Операции',
              'Админы',
              'Настройки',
            ];
      final icons = isParentMode
          ? const <IconData>[
              Icons.dashboard,
              Icons.how_to_reg,
              Icons.child_care,
              Icons.shopping_bag,
              Icons.task_alt,
              Icons.settings,
            ]
          : const <IconData>[
              Icons.dashboard,
              Icons.how_to_reg,
              Icons.shopping_cart,
              Icons.task_alt,
              Icons.workspace_premium,
              Icons.payments,
              Icons.query_stats,
              Icons.build,
              Icons.admin_panel_settings,
              Icons.settings,
            ];
      return Scaffold(
        appBar: AppBar(title: Text(labels[_index])),
        drawer: Drawer(
          child: ListView.builder(
            itemCount: labels.length,
            itemBuilder: (context, i) => ListTile(
              leading: Icon(icons[i]),
              title: Text(labels[i]),
              selected: i == _index,
              onTap: () {
                setState(() => _index = i);
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
        body: SafeArea(child: pages[_index]),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.selected,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.dashboard,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  const Text('Admin'),
                  if (!_checkedAdmin)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            destinations: isParentMode
                ? const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Дашборд'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.how_to_reg),
                      label: Text('Запросы'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.child_care),
                      label: Text('Дети'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_bag),
                      label: Text('Товары'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.task_alt),
                      label: Text('Квесты'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Настройки'),
                    ),
                  ]
                : const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Дашборд'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.how_to_reg),
                      label: Text('Запросы'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_cart),
                      label: Text('Покупки'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.task_alt),
                      label: Text('Квесты'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.workspace_premium),
                      label: Text('Промо/Подписки'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.payments),
                      label: Text('Платежи'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.query_stats),
                      label: Text('Аналитика'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.build),
                      label: Text('Операции'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.admin_panel_settings),
                      label: Text('Админы'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Настройки'),
                    ),
                  ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}

class _ParentChildrenPage extends StatefulWidget {
  const _ParentChildrenPage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });

  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_ParentChildrenPage> createState() => _ParentChildrenPageState();
}

class _ParentChildrenPageState extends State<_ParentChildrenPage> {
  bool _busy = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _deleteChild(String childId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ребёнка'),
        content: const Text(
          'Ребёнок будет удалён из семьи полностью. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo.deleteChild(
        accessToken: widget.accessToken,
        role: widget.role,
        childId: childId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ребёнок удалён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editChild(Map<String, dynamic> row) async {
    if (_busy) return;
    final currentDisplayName = (row['displayName'] ?? '').toString().trim();
    bool isActive = row['isActive'] == true;
    final firstName = TextEditingController(
      text: (row['firstName'] ?? '').toString().trim().isNotEmpty
          ? (row['firstName'] ?? '').toString()
          : (currentDisplayName.split(' ').isNotEmpty
                ? currentDisplayName.split(' ').first
                : ''),
    );
    final lastName = TextEditingController(
      text: (row['lastName'] ?? '').toString().trim().isNotEmpty
          ? (row['lastName'] ?? '').toString()
          : (currentDisplayName.split(' ').length > 1
                ? currentDisplayName.split(' ').skip(1).join(' ')
                : ''),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать ребёнка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Фамилия'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: const Text('Активен'),
                onChanged: (v) => setLocalState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo.updateChild(
        accessToken: widget.accessToken,
        role: widget.role,
        childId: (row['childId'] ?? '').toString(),
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        isActive: isActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Данные ребёнка обновлены')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка редактирования: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Дети'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _busy ? null : () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.parentChildren(
                accessToken: widget.accessToken,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return const Text('Дети не найдены');
                return Column(
                  children: rows.map((row) {
                    final childId = (row['childId'] ?? '').toString();
                    final displayName = (row['displayName'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.child_care),
                        title: Text(
                          displayName.isEmpty ? childId : displayName,
                        ),
                        subtitle: Text(
                          '$childId | active: ${row['isActive'] == true ? 'yes' : 'no'}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: _busy ? null : () => _editChild(row),
                              child: const Text('Редактировать'),
                            ),
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () => _deleteChild(childId),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentProductsPage extends StatefulWidget {
  const _ParentProductsPage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });

  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_ParentProductsPage> createState() => _ParentProductsPageState();
}

class _ParentProductsPageState extends State<_ParentProductsPage> {
  bool _busy = false;

  Future<void> _editProduct(Map<String, dynamic> row) async {
    if (_busy) return;
    final title = TextEditingController(text: (row['title'] ?? '').toString());
    final description = TextEditingController(
      text: (row['description'] ?? '').toString(),
    );
    final price = TextEditingController(text: ((row['price'] ?? 0).toString()));
    bool isActive = row['isActive'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать товар'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Цена'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: const Text('Активен'),
                  onChanged: (v) => setLocalState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final parsedPrice = int.tryParse(price.text.trim());
    if (parsedPrice == null || parsedPrice <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цена должна быть целым числом больше 0')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.updateProduct(
        accessToken: widget.accessToken,
        role: widget.role,
        productId: (row['id'] ?? '').toString(),
        title: title.text.trim(),
        description: description.text.trim(),
        price: parsedPrice,
        isActive: isActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Товар обновлён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка редактирования: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар'),
        content: const Text('Удалить товар с витрины?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo.deleteProduct(
        accessToken: widget.accessToken,
        role: widget.role,
        productId: productId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Товар удалён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Товары'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _busy ? null : () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.parentProducts(
                accessToken: widget.accessToken,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return const Text('Товары не найдены');
                return Column(
                  children: rows.map((row) {
                    final productId = (row['id'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.shopping_bag),
                        title: Text((row['title'] ?? '').toString()),
                        subtitle: Text(
                          'price: ${row['price']} | active: ${row['isActive'] == true ? 'yes' : 'no'} | id: $productId',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: _busy ? null : () => _editProduct(row),
                              child: const Text('Редактировать'),
                            ),
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () => _deleteProduct(productId),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentQuestsPage extends StatefulWidget {
  const _ParentQuestsPage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });

  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_ParentQuestsPage> createState() => _ParentQuestsPageState();
}

class _ParentQuestsPageState extends State<_ParentQuestsPage> {
  bool _busy = false;

  Future<void> _editQuest(Map<String, dynamic> row) async {
    if (_busy) return;
    final title = TextEditingController(text: (row['title'] ?? '').toString());
    final reward = TextEditingController(
      text: ((row['reward'] ?? 0).toString()),
    );
    final allStatuses = ['active', 'closed', 'archived', 'open'];
    String status = (row['status'] ?? 'active').toString().trim();
    if (!allStatuses.contains(status)) {
      allStatuses.add(status);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать квест'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(labelText: 'Награда'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: allStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocalState(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final parsedReward = int.tryParse(reward.text.trim());
    if (parsedReward == null || parsedReward < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Награда должна быть целым числом не меньше 0'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.updateQuest(
        accessToken: widget.accessToken,
        role: widget.role,
        questId: (row['id'] ?? '').toString(),
        title: title.text.trim(),
        rewardAmount: parsedReward,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Квест обновлён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка редактирования: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteQuest(String questId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить квест'),
        content: const Text('Удалить квест полностью?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo.deleteQuest(
        accessToken: widget.accessToken,
        role: widget.role,
        questId: questId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Квест удалён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Квесты'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _busy ? null : () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.parentQuests(accessToken: widget.accessToken),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return const Text('Квесты не найдены');
                return Column(
                  children: rows.map((row) {
                    final questId = (row['id'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.task_alt),
                        title: Text((row['title'] ?? '').toString()),
                        subtitle: Text(
                          'reward: ${row['reward']} | status: ${row['status']} | id: $questId',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: _busy ? null : () => _editQuest(row),
                              child: const Text('Редактировать'),
                            ),
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () => _deleteQuest(questId),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.onSignOut,
    this.repo,
    this.accessToken,
    this.role,
  });

  final Future<void> Function()? onSignOut;
  final AdminRepository? repo;
  final String? accessToken;
  final String? role;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool _busy = false;

  Future<void> _deleteChild(String childId) async {
    if (_busy || widget.repo == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ребёнка'),
        content: const Text(
          'Ребёнок будет удалён из семьи полностью. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo!.deleteChild(
        accessToken: widget.accessToken ?? '',
        role: widget.role ?? 'parent',
        childId: childId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ребёнок удалён')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParentMode = (widget.role ?? '').trim() == 'parent';
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Настройки')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isParentMode && widget.repo != null)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: widget.repo!.parentChildren(
                      accessToken: widget.accessToken ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Ошибка детей: ${snapshot.error}');
                      }
                      final rows = snapshot.data ?? const [];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дети семьи',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (rows.isEmpty) const Text('Список пуст'),
                              ...rows.map((r) {
                                final childId = (r['childId'] ?? '').toString();
                                final name = (r['displayName'] ?? '')
                                    .toString();
                                return ListTile(
                                  leading: const Icon(Icons.child_care),
                                  title: Text(name.isEmpty ? childId : name),
                                  subtitle: Text(childId),
                                  trailing: FilledButton.tonal(
                                    onPressed: _busy
                                        ? null
                                        : () => _deleteChild(childId),
                                    child: const Text('Удалить'),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти'),
                  onTap: widget.onSignOut == null
                      ? null
                      : () => widget.onSignOut!.call(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminAccountsPage extends StatefulWidget {
  const _AdminAccountsPage({
    required this.repo,
    required this.accessToken,
    required this.currentUserId,
  });

  final AdminRepository repo;
  final String accessToken;
  final String currentUserId;

  @override
  State<_AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<_AdminAccountsPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните email и пароль')));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.createAdminAccount(
        accessToken: widget.accessToken,
        email: email,
        password: password,
        displayName: _displayName.text,
      );
      if (!mounted) return;
      _email.clear();
      _password.clear();
      _displayName.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Админ добавлен')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAdmin(String userId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить администратора'),
        content: const Text('Аккаунт будет удален полностью. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await widget.repo.deleteAdminAccount(
        accessToken: widget.accessToken,
        userId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Админ удален')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Администраторы'),
          actions: [
            IconButton(
              onPressed: _busy ? null : () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _password,
                          decoration: const InputDecoration(
                            labelText: 'Пароль',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _displayName,
                          decoration: const InputDecoration(
                            labelText: 'Имя (опционально)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy || widget.accessToken.isEmpty
                                ? null
                                : _create,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Добавить администратора'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.adminAccounts(
                    accessToken: widget.accessToken,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text('Ошибка: ${snapshot.error}');
                    }
                    final rows = snapshot.data ?? const [];
                    if (rows.isEmpty)
                      return const Text('Администраторы не найдены');
                    return Column(
                      children: rows.map((row) {
                        final userId = (row['userId'] ?? '').toString();
                        final isCurrent = userId == widget.currentUserId;
                        final email = (row['email'] ?? '').toString();
                        final name = (row['displayName'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.admin_panel_settings),
                            title: Text(email),
                            subtitle: Text(name.isEmpty ? 'Без имени' : name),
                            trailing: IconButton(
                              tooltip: isCurrent
                                  ? 'Нельзя удалить себя'
                                  : 'Удалить',
                              onPressed:
                                  (_busy ||
                                      isCurrent ||
                                      widget.accessToken.isEmpty)
                                  ? null
                                  : () => _deleteAdmin(userId),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OperationsPage extends StatefulWidget {
  const _OperationsPage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });
  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<_OperationsPage> {
  Future<bool> _confirm(String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editClanName(Map<String, dynamic> row) async {
    final controller = TextEditingController(
      text: (row['clan_name'] ?? '').toString(),
    );
    final value = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить clan_name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    await widget.repo.setFamilyClanName(
      familyId: (row['id'] ?? '').toString(),
      clanName: value,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editChild(Map<String, dynamic> row) async {
    final firstName = TextEditingController(
      text: (row['firstName'] ?? '').toString(),
    );
    final lastName = TextEditingController(
      text: (row['lastName'] ?? '').toString(),
    );
    bool isActive = row['isActive'] == true;
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать ребёнка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Фамилия'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: const Text('Активен'),
                onChanged: (v) => setLocalState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (value != true) return;
    await widget.repo.updateChild(
      accessToken: widget.accessToken,
      role: widget.role,
      childId: (row['id'] ?? '').toString(),
      firstName: firstName.text.trim(),
      lastName: lastName.text.trim(),
      isActive: isActive,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editProduct(Map<String, dynamic> row) async {
    final title = TextEditingController(text: (row['title'] ?? '').toString());
    final description = TextEditingController(
      text: (row['description'] ?? '').toString(),
    );
    final price = TextEditingController(text: ((row['price'] ?? 0).toString()));
    bool isActive = row['isActive'] == true;
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать товар'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Цена'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: const Text('Активен'),
                  onChanged: (v) => setLocalState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (value != true) return;
    final parsedPrice = int.tryParse(price.text.trim());
    if (parsedPrice == null || parsedPrice <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цена должна быть целым числом больше 0')),
      );
      return;
    }
    await widget.repo.updateProduct(
      accessToken: widget.accessToken,
      role: widget.role,
      productId: (row['id'] ?? '').toString(),
      title: title.text.trim(),
      description: description.text.trim(),
      price: parsedPrice,
      isActive: isActive,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editQuest(Map<String, dynamic> row) async {
    final title = TextEditingController(text: (row['title'] ?? '').toString());
    final reward = TextEditingController(
      text: ((row['reward'] ?? 0).toString()),
    );
    final allStatuses = ['open', 'closed', 'archived'];
    String status = (row['status'] ?? 'open').toString().trim();
    if (!allStatuses.contains(status)) {
      allStatuses.add(status);
    }
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать квест'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(labelText: 'Награда'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: allStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocalState(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (value != true) return;
    final parsedReward = int.tryParse(reward.text.trim());
    if (parsedReward == null || parsedReward < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Награда должна быть целым числом не меньше 0'),
        ),
      );
      return;
    }
    await widget.repo.updateQuest(
      accessToken: widget.accessToken,
      role: widget.role,
      questId: (row['id'] ?? '').toString(),
      title: title.text.trim(),
      rewardAmount: parsedReward,
      status: status,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Операции (CRUD)'),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.adminChildren(
                    accessToken: widget.accessToken,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка admin children: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Быстрое управление: дети',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows
                                .take(40)
                                .map(
                                  (r) => ListTile(
                                    title: Text(
                                      ([r['firstName'], r['lastName']].where(
                                        (e) => (e ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty,
                                      )).join(' '),
                                    ),
                                    subtitle: Text(
                                      'id: ${(r['id'] ?? '').toString()} | active: ${r['isActive'] == true ? 'yes' : 'no'}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editChild(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              'Удаление ребёнка',
                                              'Удалить ребёнка полностью?',
                                            );
                                            if (!ok) return;
                                            await widget.repo.deleteChild(
                                              accessToken: widget.accessToken,
                                              role: widget.role,
                                              childId: (r['id'] ?? '')
                                                  .toString(),
                                            );
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.adminProducts(
                    accessToken: widget.accessToken,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка admin products: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Быстрое управление: товары',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows
                                .take(40)
                                .map(
                                  (r) => ListTile(
                                    title: Text((r['title'] ?? '').toString()),
                                    subtitle: Text(
                                      'price: ${r['price']} | active: ${r['isActive'] == true ? 'yes' : 'no'} | id: ${(r['id'] ?? '').toString()}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editProduct(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              'Удаление товара',
                                              'Удалить товар с витрины?',
                                            );
                                            if (!ok) return;
                                            await widget.repo.deleteProduct(
                                              accessToken: widget.accessToken,
                                              role: widget.role,
                                              productId: (r['id'] ?? '')
                                                  .toString(),
                                            );
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.adminQuests(
                    accessToken: widget.accessToken,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка admin quests: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Быстрое управление: квесты',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows
                                .take(40)
                                .map(
                                  (r) => ListTile(
                                    title: Text((r['title'] ?? '').toString()),
                                    subtitle: Text(
                                      'reward: ${r['reward']} | status: ${(r['status'] ?? '').toString()} | id: ${(r['id'] ?? '').toString()}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editQuest(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              'Удаление квеста',
                                              'Удалить квест полностью?',
                                            );
                                            if (!ok) return;
                                            await widget.repo.deleteQuest(
                                              accessToken: widget.accessToken,
                                              role: widget.role,
                                              questId: (r['id'] ?? '')
                                                  .toString(),
                                            );
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.readTable(
                    'families',
                    columns: 'id, family_code, clan_name, created_at',
                    orderBy: 'created_at',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка families: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Семьи',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows
                                .take(40)
                                .map(
                                  (r) => ListTile(
                                    title: Text('${r['family_code']}'),
                                    subtitle: Text(
                                      'clan_name: ${r['clan_name'] ?? '-'}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editClanName(r),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.readTable(
                    'profiles',
                    columns:
                        'user_id, family_id, role, display_name, created_at',
                    orderBy: 'created_at',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка profiles: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Профили',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows.take(60).map((r) {
                              final currentRole = (r['role'] ?? 'parent')
                                  .toString();
                              return ListTile(
                                title: Text(
                                  (r['display_name'] ?? '').toString().isEmpty
                                      ? (r['user_id'] ?? '').toString()
                                      : (r['display_name'] ?? '').toString(),
                                ),
                                subtitle: Text(
                                  'family: ${r['family_id']} | role: $currentRole',
                                ),
                                trailing: DropdownButton<String>(
                                  value: currentRole,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'admin',
                                      child: Text('admin'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'parent',
                                      child: Text('parent'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'child',
                                      child: Text('child'),
                                    ),
                                  ],
                                  onChanged: (v) async {
                                    final nextRole = (v ?? '').trim();
                                    if (nextRole.isEmpty ||
                                        nextRole == currentRole)
                                      return;
                                    final ok = await _confirm(
                                      'Смена роли',
                                      'Изменить роль на "$nextRole"?',
                                    );
                                    if (!ok) return;
                                    await widget.repo.setProfileRole(
                                      userId: (r['user_id'] ?? '').toString(),
                                      role: nextRole,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.readTable(
                    'children',
                    columns: 'id, display_name, is_active, created_at',
                    orderBy: 'created_at',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка children: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дети',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows.take(60).map((r) {
                              final active = r['is_active'] == true;
                              return SwitchListTile(
                                value: active,
                                title: Text(
                                  (r['display_name'] ?? '').toString(),
                                ),
                                subtitle: Text((r['id'] ?? '').toString()),
                                onChanged: (v) async {
                                  await widget.repo.setChildActive(
                                    childId: (r['id'] ?? '').toString(),
                                    isActive: v,
                                  );
                                  if (mounted) setState(() {});
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.readTable(
                    'shop_products',
                    columns: 'id, title, price, is_active, created_at',
                    orderBy: 'created_at',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка shop_products: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Товары',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows.take(60).map((r) {
                              final active = r['is_active'] == true;
                              return SwitchListTile(
                                value: active,
                                title: Text('${r['title']} (${r['price']})'),
                                subtitle: Text((r['id'] ?? '').toString()),
                                onChanged: (v) async {
                                  await widget.repo.setProductActive(
                                    productId: (r['id'] ?? '').toString(),
                                    isActive: v,
                                  );
                                  if (mounted) setState(() {});
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.readTable(
                    'family_subscriptions',
                    columns:
                        'id, family_id, plan_code, status, expires_at, created_at',
                    orderBy: 'created_at',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка subscriptions: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Подписки',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows.take(40).map((r) {
                              final status = (r['status'] ?? '').toString();
                              return ListTile(
                                title: Text(
                                  'family ${r['family_id']} | ${r['plan_code']}',
                                ),
                                subtitle: Text(
                                  'status: $status | expires: ${r['expires_at']}',
                                ),
                                trailing: status == 'active'
                                    ? OutlinedButton(
                                        onPressed: () async {
                                          final ok = await _confirm(
                                            'Отмена подписки',
                                            'Отменить подписку?',
                                          );
                                          if (!ok) return;
                                          await widget.repo.cancelSubscription(
                                            subscriptionId: (r['id'] ?? '')
                                                .toString(),
                                          );
                                          if (mounted) setState(() {});
                                        },
                                        child: const Text('Отменить'),
                                      )
                                    : null,
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.promoCodes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка promo_codes: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Промокоды (удаление)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...rows
                                .take(40)
                                .map(
                                  (r) => ListTile(
                                    title: Text((r['code'] ?? '').toString()),
                                    subtitle: Text(
                                      'uses ${r['used_count']}/${r['max_uses']}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        final ok = await _confirm(
                                          'Удаление промокода',
                                          'Удалить ${r['code']}?',
                                        );
                                        if (!ok) return;
                                        await widget.repo.deletePromoCode(
                                          (r['id'] ?? '').toString(),
                                        );
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });

  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, int>> _loadCounts() async {
    if (widget.role == 'parent') {
      final family = await widget.repo.familyContext(
        accessToken: widget.accessToken,
      );
      final members = await widget.repo.parentMembers(
        accessToken: widget.accessToken,
      );
      final children = await widget.repo.parentChildren(
        accessToken: widget.accessToken,
      );
      final pending = await widget.repo.accessRequestsPending(
        accessToken: widget.accessToken,
        role: widget.role,
      );
      return {
        'families': family.isEmpty ? 0 : 1,
        'profiles': members.length,
        'children': children.length,
        'pending_requests': pending.length,
      };
    }

    final families = await widget.repo.readTable('families', columns: 'id');
    final profiles = await widget.repo.readTable(
      'profiles',
      columns: 'user_id',
    );
    final children = await widget.repo.readTable('children', columns: 'id');
    final pendingRequests = await widget.repo
        .readTable('child_access_requests', columns: 'id, status')
        .then((rows) => rows.where((r) => r['status'] == 'pending').toList());

    return {
      'families': families.length,
      'profiles': profiles.length,
      'children': children.length,
      'pending_requests': pendingRequests.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Дашборд')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, int>>(
              future: _loadCounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                final c = snapshot.data ?? const <String, int>{};

                Widget stat(String title, int value, IconData icon) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(icon),
                          const SizedBox(width: 10),
                          Expanded(child: Text(title)),
                          Text(
                            '$value',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    stat('Семей', c['families'] ?? 0, Icons.home),
                    stat('Профилей', c['profiles'] ?? 0, Icons.people),
                    stat('Детей', c['children'] ?? 0, Icons.child_care),
                    stat(
                      'Запросов на вход (pending)',
                      c['pending_requests'] ?? 0,
                      Icons.how_to_reg,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Быстрые подсказки: сюда можно добавить графики, фильтры по датам, '
                      'и быстрые действия (создать промокод/деактивировать ребёнка/отозвать устройство).',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessRequestsQueuePage extends StatefulWidget {
  const _AccessRequestsQueuePage({
    required this.repo,
    required this.accessToken,
    required this.role,
  });
  final AdminRepository repo;
  final String accessToken;
  final String role;

  @override
  State<_AccessRequestsQueuePage> createState() =>
      _AccessRequestsQueuePageState();
}

class _AccessRequestsQueuePageState extends State<_AccessRequestsQueuePage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _reject(String id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Причина отказа'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Опционально'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await widget.repo.rejectAccessRequest(
      id,
      accessToken: widget.accessToken,
      role: widget.role,
      reason: reason,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Запросы на вход (pending)'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.accessRequestsPending(
                accessToken: widget.accessToken,
                role: widget.role,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) return const Text('Нет pending запросов');

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => downloadCsv(
                          'access_requests_pending.csv',
                          rows,
                          const [
                            'id',
                            'family_id',
                            'child_first_name',
                            'device_id',
                            'status',
                            'created_at',
                          ],
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Экспорт CSV'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rows.map((r) {
                      final title = (r['child_first_name'] ?? '')
                          .toString()
                          .trim();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'Без имени' : title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text('id: ${r['id']}'),
                              Text('family_id: ${r['family_id']}'),
                              Text('device_id: ${r['device_id']}'),
                              Text('created_at: ${r['created_at']}'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _reject((r['id'] ?? '').toString()),
                                      child: const Text('Отклонить'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        await widget.repo.approveAccessRequest(
                                          (r['id'] ?? '').toString(),
                                          accessToken: widget.accessToken,
                                          role: widget.role,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      child: const Text('Подтвердить'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PurchasesQueuePage extends StatefulWidget {
  const _PurchasesQueuePage({required this.repo});
  final AdminRepository repo;

  @override
  State<_PurchasesQueuePage> createState() => _PurchasesQueuePageState();
}

class _PurchasesQueuePageState extends State<_PurchasesQueuePage> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Покупки (requested)'),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.purchasesRequested(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) return const Text('Нет requested покупок');

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            downloadCsv('purchases_requested.csv', rows, const [
                              'id',
                              'product_id',
                              'child_id',
                              'quantity',
                              'total_price',
                              'frozen_amount',
                              'status',
                              'created_at',
                            ]),
                        icon: const Icon(Icons.download),
                        label: const Text('Экспорт CSV'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rows.map((r) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'purchase: ${r['id']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('product_id: ${r['product_id']}'),
                              Text('child_id: ${r['child_id']}'),
                              Text(
                                'qty: ${r['quantity']} total: ${r['total_price']} frozen: ${r['frozen_amount']}',
                              ),
                              Text('created_at: ${r['created_at']}'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await widget.repo.decidePurchase(
                                          (r['id'] ?? '').toString(),
                                          false,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      child: const Text('Отклонить'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        await widget.repo.decidePurchase(
                                          (r['id'] ?? '').toString(),
                                          true,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      child: const Text('Подтвердить'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestReviewQueuePage extends StatefulWidget {
  const _QuestReviewQueuePage({required this.repo});
  final AdminRepository repo;

  @override
  State<_QuestReviewQueuePage> createState() => _QuestReviewQueuePageState();
}

class _QuestReviewQueuePageState extends State<_QuestReviewQueuePage> {
  Future<void> _review(Map<String, dynamic> row, bool approve) async {
    final controller = TextEditingController();
    final comment = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Комментарий (approve)' : 'Комментарий (reject)'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await widget.repo.reviewQuest(
      questId: (row['quest_id'] ?? '').toString(),
      childId: (row['child_id'] ?? '').toString(),
      approve: approve,
      comment: comment,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Квесты на проверку (submitted)'),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.repo.questSubmissions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) return const Text('Нет submitted квестов');

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            downloadCsv('quests_submitted.csv', rows, const [
                              'quest_id',
                              'quest_title',
                              'child_id',
                              'child_name',
                              'status',
                              'submitted_at',
                              'reward_amount',
                            ]),
                        icon: const Icon(Icons.download),
                        label: const Text('Экспорт CSV'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rows.map((r) {
                      final questTitle = (r['quest_title'] ?? '').toString();
                      final childName = (r['child_name'] ?? '').toString();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                questTitle.isEmpty
                                    ? 'quest: ${r['quest_id']}'
                                    : questTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'child: ${childName.isEmpty ? r['child_id'] : childName}',
                              ),
                              Text(
                                'submitted_at: ${r['submitted_at']} reward: ${r['reward_amount']}',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _review(r, false),
                                      child: const Text('Отклонить'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _review(r, true),
                                      child: const Text('Подтвердить'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoAndSubsPage extends StatefulWidget {
  const _PromoAndSubsPage({required this.repo});
  final AdminRepository repo;

  @override
  State<_PromoAndSubsPage> createState() => _PromoAndSubsPageState();
}

class _PromoAndSubsPageState extends State<_PromoAndSubsPage> {
  final _code = TextEditingController();
  final _duration = TextEditingController(text: '30');
  final _uses = TextEditingController(text: '1');
  String _plan = 'premium';
  int _expDays = 3;

  @override
  void dispose() {
    _code.dispose();
    _duration.dispose();
    _uses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Промокоды / Подписки'),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Создать промокод',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _code,
                          decoration: const InputDecoration(labelText: 'CODE'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _plan,
                          items: const [
                            DropdownMenuItem(
                              value: 'basic',
                              child: Text('basic'),
                            ),
                            DropdownMenuItem(
                              value: 'premium',
                              child: Text('premium'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _plan = v ?? 'premium'),
                          decoration: const InputDecoration(
                            labelText: 'plan_code',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _duration,
                          decoration: const InputDecoration(
                            labelText: 'duration_days',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _uses,
                          decoration: const InputDecoration(
                            labelText: 'max_uses',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () async {
                            await widget.repo.createPromoCode(
                              code: _code.text,
                              planCode: _plan,
                              durationDays:
                                  int.tryParse(_duration.text.trim()) ?? 30,
                              maxUses: int.tryParse(_uses.text.trim()) ?? 1,
                            );
                            if (mounted) setState(() {});
                          },
                          child: const Text('Создать'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.promoCodes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError)
                      return Text('Ошибка promo_codes: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'promo_codes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  downloadCsv('promo_codes.csv', rows, const [
                                    'id',
                                    'code',
                                    'plan_code',
                                    'duration_days',
                                    'max_uses',
                                    'used_count',
                                    'is_active',
                                    'created_at',
                                  ]),
                              icon: const Icon(Icons.download),
                              label: const Text('Экспорт CSV'),
                            ),
                            const SizedBox(height: 8),
                            if (rows.isEmpty) const Text('Нет промокодов'),
                            ...rows.map((r) {
                              final active = r['is_active'] == true;
                              return ListTile(
                                title: Text('${r['code']} (${r['plan_code']})'),
                                subtitle: Text(
                                  'used ${r['used_count']}/${r['max_uses']} duration ${r['duration_days']}d',
                                ),
                                trailing: Switch(
                                  value: active,
                                  onChanged: (v) async {
                                    await widget.repo.setPromoActive(
                                      (r['id'] ?? '').toString(),
                                      v,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Подписки: истекают в ближайшие N дней',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('N='),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _expDays,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1')),
                                DropdownMenuItem(value: 3, child: Text('3')),
                                DropdownMenuItem(value: 7, child: Text('7')),
                                DropdownMenuItem(value: 14, child: Text('14')),
                                DropdownMenuItem(value: 30, child: Text('30')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _expDays = v ?? 3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: widget.repo.subscriptionsExpiringInDays(
                            _expDays,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snapshot.hasError)
                              return Text(
                                'Ошибка subscriptions: ${snapshot.error}',
                              );
                            final rows = snapshot.data ?? const [];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => downloadCsv(
                                    'subscriptions_expiring_${_expDays}d.csv',
                                    rows,
                                    const [
                                      'id',
                                      'family_id',
                                      'plan_code',
                                      'status',
                                      'expires_at',
                                      'created_at',
                                      'source',
                                    ],
                                  ),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Экспорт CSV'),
                                ),
                                const SizedBox(height: 8),
                                if (rows.isEmpty)
                                  const Text('Нет подписок в окне'),
                                ...rows.map(
                                  (r) => ListTile(
                                    title: Text('family: ${r['family_id']}'),
                                    subtitle: Text(
                                      'plan ${r['plan_code']} expires ${r['expires_at']}',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentsAndWebhooksPage extends StatefulWidget {
  const _PaymentsAndWebhooksPage({required this.repo});
  final AdminRepository repo;

  @override
  State<_PaymentsAndWebhooksPage> createState() =>
      _PaymentsAndWebhooksPageState();
}

class _PaymentsAndWebhooksPageState extends State<_PaymentsAndWebhooksPage> {
  String? _status;
  bool? _processed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Платежи / Вебхуки'),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _status,
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('status: ALL'),
                              ),
                              DropdownMenuItem(
                                value: 'created',
                                child: Text('created'),
                              ),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('pending'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('paid'),
                              ),
                              DropdownMenuItem(
                                value: 'canceled',
                                child: Text('canceled'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _status = v),
                            decoration: const InputDecoration(
                              labelText: 'payment_orders.status',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<bool?>(
                            initialValue: _processed,
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('webhook processed: ALL'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('false'),
                              ),
                              DropdownMenuItem(
                                value: true,
                                child: Text('true'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _processed = v),
                            decoration: const InputDecoration(
                              labelText: 'payment_webhook_events.processed',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.paymentOrders(status: _status),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка payment_orders: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'payment_orders',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => downloadCsv(
                                'payment_orders.csv',
                                rows,
                                const [
                                  'id',
                                  'family_id',
                                  'amount_rub',
                                  'status',
                                  'plan_code',
                                  'provider_payment_id',
                                  'created_at',
                                  'paid_at',
                                ],
                              ),
                              icon: const Icon(Icons.download),
                              label: const Text('Экспорт CSV'),
                            ),
                            const SizedBox(height: 8),
                            if (rows.isEmpty)
                              const Text('Нет платежей по фильтру'),
                            ...rows
                                .take(50)
                                .map(
                                  (r) => ListTile(
                                    title: Text('${r['id']} (${r['status']})'),
                                    subtitle: Text(
                                      'family ${r['family_id']} amount ${r['amount_rub']} created ${r['created_at']}',
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repo.webhookEvents(
                    provider: 'yookassa',
                    processed: _processed,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text('Ошибка webhook_events: ${snapshot.error}');
                    final rows = snapshot.data ?? const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'payment_webhook_events',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => downloadCsv(
                                'payment_webhook_events.csv',
                                rows,
                                const [
                                  'id',
                                  'provider',
                                  'event_type',
                                  'event_id',
                                  'processed',
                                  'created_at',
                                ],
                              ),
                              icon: const Icon(Icons.download),
                              label: const Text('Экспорт CSV'),
                            ),
                            const SizedBox(height: 8),
                            if (rows.isEmpty)
                              const Text('Нет событий по фильтру'),
                            ...rows
                                .take(50)
                                .map(
                                  (r) => ListTile(
                                    title: Text(
                                      '${r['event_type']} processed=${r['processed']}',
                                    ),
                                    subtitle: Text(
                                      'event_id=${r['event_id']} created=${r['created_at']}',
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsPage extends StatefulWidget {
  const _AnalyticsPage({required this.repo});
  final AdminRepository repo;

  @override
  State<_AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<_AnalyticsPage> {
  String _period = '7d'; // today | 7d | 30d

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Аналитика'),
          actions: [
            DropdownButton<String>(
              value: _period,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                DropdownMenuItem(value: '7d', child: Text('7 дней')),
                DropdownMenuItem(value: '30d', child: Text('30 дней')),
              ],
              onChanged: (v) => setState(() => _period = v ?? '7d'),
            ),
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: widget.repo.adminCounts(_period),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const LinearProgressIndicator();
                if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
                final m = snapshot.data ?? const {};

                Widget stat(String title, Object? value, IconData icon) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(icon),
                          const SizedBox(width: 10),
                          Expanded(child: Text(title)),
                          Text(
                            '${value ?? 0}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rows = [
                  {'metric': 'families_new', 'value': m['families_new'] ?? 0},
                  {'metric': 'children_new', 'value': m['children_new'] ?? 0},
                  {
                    'metric': 'access_requests_new',
                    'value': m['access_requests_new'] ?? 0,
                  },
                  {'metric': 'purchases_new', 'value': m['purchases_new'] ?? 0},
                  {
                    'metric': 'quests_submitted',
                    'value': m['quests_submitted'] ?? 0,
                  },
                ];

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => downloadCsv(
                          'analytics_$_period.csv',
                          rows,
                          const ['metric', 'value'],
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Экспорт CSV'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    stat('Новые семьи', m['families_new'], Icons.home),
                    stat('Новые дети', m['children_new'], Icons.child_care),
                    stat(
                      'Новые запросы на вход',
                      m['access_requests_new'],
                      Icons.how_to_reg,
                    ),
                    stat(
                      'Новые покупки',
                      m['purchases_new'],
                      Icons.shopping_cart,
                    ),
                    stat(
                      'Submitted квесты',
                      m['quests_submitted'],
                      Icons.task_alt,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
