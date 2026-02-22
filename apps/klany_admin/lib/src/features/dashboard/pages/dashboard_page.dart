import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/env.dart';
import '../../../core/sdk.dart';
import '../../auth/admin_session.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _index = 0;
  bool _checkedAdmin = false;
  bool _adminCheckStarted = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkAdmin(AdminSession session) async {
    final api = Sdk.apiOrNull;
    if (!Env.hasApiConfig || api == null) {
      if (mounted) setState(() => _checkedAdmin = true);
      return;
    }
    try {
      final res = await api.getJson('/me', accessToken: session.accessToken);
      final user = (res['user'] as Map?) ?? const <String, dynamic>{};
      final role = (user['role'] ?? '').toString();
      if (role != 'admin') throw Exception('Нет доступа: требуется роль admin');

      if (mounted) setState(() => _checkedAdmin = true);
    } catch (_) {
      await ref.read(adminSessionProvider.notifier).clear();
      if (!mounted) return;
      setState(() => _checkedAdmin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступа: требуется роль admin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(adminSessionProvider);
    final session = sessionAsync.asData?.value;

    if (session != null && !_adminCheckStarted) {
      _adminCheckStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin(session));
    }

    final repo = _AdminRepository(
      api: Sdk.apiOrNull,
      accessToken: session?.accessToken,
    );

    final pages = <Widget>[
      _TablePage(
        title: 'Семьи',
        future: repo.families(),
        columns: const ['id', 'ownerUserId', 'familyCode', 'clanName'],
      ),
      _TablePage(
        title: 'Пользователи',
        future: repo.profiles(),
        columns: const ['userId', 'familyId', 'role', 'displayName'],
      ),
      _ChildrenAdminPage(repo: repo),
      _TablePage(
        title: 'Квесты',
        future: repo.quests(),
        columns: const ['id', 'familyId', 'title', 'status', 'questType', 'reward'],
      ),
      _TablePage(
        title: 'Магазин: товары',
        future: repo.products(),
        columns: const ['id', 'familyId', 'title', 'price', 'isActive'],
      ),
      _PurchasesAdminPage(repo: repo),
      _SubscriptionsAdminPage(repo: repo),
      _PromocodesAdminPage(repo: repo),
      _TablePage(
        title: 'Платежи',
        future: repo.payments(),
        columns: const ['id', 'familyId', 'amountRub', 'status', 'planCode', 'providerPaymentId', 'createdAt'],
      ),
      _RequestsAdminPage(repo: repo),
      _TablePage(
        title: 'Уведомления',
        future: repo.notifications(),
        columns: const ['id', 'familyId', 'nType', 'isRead', 'createdAt'],
      ),
      _TablePage(
        title: 'Аудит',
        future: repo.auditLogs(),
        columns: const ['id', 'familyId', 'actorUserId', 'action', 'createdAt'],
      ),
      _SettingsSection(onSignOut: () => ref.read(adminSessionProvider.notifier).clear()),
    ];

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
                  Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary),
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
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home), label: Text('Семьи')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Пользов.')),
              NavigationRailDestination(icon: Icon(Icons.child_care), label: Text('Дети')),
              NavigationRailDestination(icon: Icon(Icons.task_alt), label: Text('Квесты')),
              NavigationRailDestination(icon: Icon(Icons.store), label: Text('Товары')),
              NavigationRailDestination(icon: Icon(Icons.shopping_cart), label: Text('Покупки')),
              NavigationRailDestination(icon: Icon(Icons.workspace_premium), label: Text('Подписки')),
              NavigationRailDestination(icon: Icon(Icons.redeem), label: Text('Промо')),
              NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Платежи')),
              NavigationRailDestination(icon: Icon(Icons.mark_email_unread), label: Text('Запросы')),
              NavigationRailDestination(icon: Icon(Icons.notifications), label: Text('Уведомл.')),
              NavigationRailDestination(icon: Icon(Icons.history), label: Text('Аудит')),
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

class _TablePage extends StatelessWidget {
  const _TablePage({
    required this.title,
    required this.future,
    required this.columns,
  });

  final String title;
  final Future<List<Map<String, dynamic>>> future;
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return CustomScrollView(
          slivers: [
            SliverAppBar(pinned: true, title: Text(title)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(),
                    ...rows.map(
                      (row) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: columns
                                .map((c) => Text('$c: ${row[c] ?? ''}'))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildrenAdminPage extends StatefulWidget {
  const _ChildrenAdminPage({required this.repo});
  final _AdminRepository repo;

  @override
  State<_ChildrenAdminPage> createState() => _ChildrenAdminPageState();
}

class _ChildrenAdminPageState extends State<_ChildrenAdminPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.repo.children(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Дети')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: rows
                      .map(
                        (row) => Card(
                          child: ListTile(
                            title: Text((row['displayName'] ?? '').toString()),
                            subtitle: Text('active: ${row['isActive']}'),
                            trailing: TextButton(
                              onPressed: () async {
                                await widget.repo.deactivateChild(row['id'].toString());
                                if (context.mounted) setState(() {});
                              },
                              child: const Text('Деактивировать'),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubscriptionsAdminPage extends StatelessWidget {
  const _SubscriptionsAdminPage({required this.repo});
  final _AdminRepository repo;

  @override
  Widget build(BuildContext context) {
    return _TablePage(
      title: 'Подписки',
      future: repo.subscriptions(),
      columns: const ['id', 'familyId', 'planCode', 'status', 'expiresAt', 'source'],
    );
  }
}

class _PromocodesAdminPage extends StatefulWidget {
  const _PromocodesAdminPage({required this.repo});
  final _AdminRepository repo;

  @override
  State<_PromocodesAdminPage> createState() => _PromocodesAdminPageState();
}

class _PromocodesAdminPageState extends State<_PromocodesAdminPage> {
  final _code = TextEditingController();
  final _days = TextEditingController(text: '30');
  final _uses = TextEditingController(text: '1');
  String _plan = 'premium';

  @override
  void dispose() {
    _code.dispose();
    _days.dispose();
    _uses.dispose();
    super.dispose();
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.bytes == null) return;
    final text = utf8.decode(result.files.single.bytes!);
    final rows = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (final row in rows.skip(1)) {
      final cols = row.split(',').map((v) => v.trim()).toList();
      if (cols.length < 4) continue;
      await widget.repo.createPromoCode(
        code: cols[0],
        planCode: cols[1],
        durationDays: int.tryParse(cols[2]) ?? 30,
        maxUses: int.tryParse(cols[3]) ?? 1,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV импорт завершён')));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.repo.promocodes(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Промокоды')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(controller: _code, decoration: const InputDecoration(labelText: 'Код')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _plan,
                      items: const [
                        DropdownMenuItem(value: 'basic', child: Text('basic')),
                        DropdownMenuItem(value: 'premium', child: Text('premium')),
                      ],
                      onChanged: (v) => setState(() => _plan = v ?? 'premium'),
                      decoration: const InputDecoration(labelText: 'Тариф'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _days,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Дней'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uses,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Макс. использований'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await widget.repo.createPromoCode(
                                code: _code.text.trim(),
                                planCode: _plan,
                                durationDays: int.tryParse(_days.text.trim()) ?? 30,
                                maxUses: int.tryParse(_uses.text.trim()) ?? 1,
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text('Создать'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _importCsv,
                            child: const Text('CSV импорт'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...rows.map(
                      (row) => Card(
                        child: ListTile(
                          title: Text('${row['code']} (${row['planCode']})'),
                          subtitle: Text('used ${row['usedCount']}/${row['maxUses']}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestsAdminPage extends StatefulWidget {
  const _RequestsAdminPage({required this.repo});
  final _AdminRepository repo;

  @override
  State<_RequestsAdminPage> createState() => _RequestsAdminPageState();
}

class _PurchasesAdminPage extends StatefulWidget {
  const _PurchasesAdminPage({required this.repo});
  final _AdminRepository repo;

  @override
  State<_PurchasesAdminPage> createState() => _PurchasesAdminPageState();
}

class _PurchasesAdminPageState extends State<_PurchasesAdminPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.repo.purchases(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Магазин: покупки')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: rows
                      .map(
                        (row) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('id: ${row['id']}'),
                                Text('child: ${row['childId']}'),
                                Text('price: ${row['totalPrice']}'),
                                Text('status: ${row['status']}'),
                                if (row['status'] == 'requested')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            await widget.repo.decidePurchase(
                                              row['id'].toString(),
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
                                              row['id'].toString(),
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
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestsAdminPageState extends State<_RequestsAdminPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.repo.pendingRequests(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Запросы на вход')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: rows
                      .map(
                        (row) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['lastName'] ?? ''} ${row['firstName'] ?? ''}',
                                ),
                                Text('family: ${row['familyId']}'),
                                Text('device: ${row['deviceId']}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await widget.repo.rejectRequest(row['id'].toString());
                                          if (mounted) setState(() {});
                                        },
                                        child: const Text('Отклонить'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () async {
                                          await widget.repo.approveRequest(row['id'].toString());
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
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminRepository {
  _AdminRepository({required this.api, required this.accessToken});

  final ApiClient? api;
  final String? accessToken;

  bool get _hasAuth => api != null && (accessToken ?? '').isNotEmpty;

  Future<List<Map<String, dynamic>>> families() => _getList('/admin/families');
  Future<List<Map<String, dynamic>>> profiles() => _getList('/admin/profiles');
  Future<List<Map<String, dynamic>>> children() => _getList('/admin/children');
  Future<List<Map<String, dynamic>>> quests() => _getList('/admin/quests');
  Future<List<Map<String, dynamic>>> products() => _getList('/admin/products');
  Future<List<Map<String, dynamic>>> purchases() => _getList('/admin/purchases');
  Future<List<Map<String, dynamic>>> subscriptions() => _getList('/admin/subscriptions');
  Future<List<Map<String, dynamic>>> promocodes() => _getList('/admin/promocodes');
  Future<List<Map<String, dynamic>>> payments() => _getList('/admin/payments');
  Future<List<Map<String, dynamic>>> notifications() => _getList('/admin/notifications');
  Future<List<Map<String, dynamic>>> auditLogs() => _getList('/admin/audit');
  Future<List<Map<String, dynamic>>> pendingRequests() =>
      _getList('/admin/access-requests', query: const {'status': 'pending'});

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, String>? query,
  }) async {
    if (!_hasAuth) return const [];
    final res = await api!.getJson(path, accessToken: accessToken, query: query);
    final items = res['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final data = res['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<void> createPromoCode({
    required String code,
    required String planCode,
    required int durationDays,
    required int maxUses,
  }) async {
    if (!_hasAuth) return;
    await api!.postJson(
      '/admin/promocodes',
      accessToken: accessToken,
      body: <String, dynamic>{
        'code': code.toUpperCase(),
        'planCode': planCode,
        'durationDays': durationDays,
        'maxUses': maxUses,
      },
    );
  }

  Future<void> approveRequest(String requestId) async {
    if (!_hasAuth) return;
    await api!.postJson(
      '/admin/access-requests/$requestId/approve',
      accessToken: accessToken,
    );
  }

  Future<void> rejectRequest(String requestId) async {
    if (!_hasAuth) return;
    await api!.postJson(
      '/admin/access-requests/$requestId/reject',
      accessToken: accessToken,
    );
  }

  Future<void> deactivateChild(String childId) async {
    if (!_hasAuth) return;
    await api!.postJson(
      '/admin/children/$childId/deactivate',
      accessToken: accessToken,
    );
  }

  Future<void> decidePurchase(String purchaseId, bool approve) async {
    if (!_hasAuth) return;
    await api!.postJson(
      '/admin/purchases/$purchaseId/decide',
      accessToken: accessToken,
      body: <String, dynamic>{'approve': approve},
    );
  }
}

