import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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
  final _repo = _AdminRepository();

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
      final row =
          await client.from('profiles').select('role').eq('user_id', user.id).maybeSingle();
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
    } catch (_) {
      if (mounted) setState(() => _checkedAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _TablePage(
        title: 'Семьи',
        future: _repo.families(),
        columns: const ['id', 'owner_user_id', 'family_code', 'clan_name'],
      ),
      _TablePage(
        title: 'Пользователи',
        future: _repo.profiles(),
        columns: const ['user_id', 'family_id', 'role', 'display_name'],
      ),
      _ChildrenAdminPage(repo: _repo),
      _TablePage(
        title: 'Квесты',
        future: _repo.quests(),
        columns: const ['id', 'family_id', 'title', 'status', 'quest_type', 'reward_amount'],
      ),
      _TablePage(
        title: 'Магазин: товары',
        future: _repo.products(),
        columns: const ['id', 'family_id', 'title', 'price', 'is_active'],
      ),
      _PurchasesAdminPage(repo: _repo),
      _SubscriptionsAdminPage(repo: _repo),
      _PromocodesAdminPage(repo: _repo),
      _TablePage(
        title: 'Платежи',
        future: _repo.payments(),
        columns: const ['id', 'family_id', 'provider', 'amount_rub', 'status', 'plan_code'],
      ),
      _RequestsAdminPage(repo: _repo),
      _TablePage(
        title: 'Уведомления',
        future: _repo.notifications(),
        columns: const ['id', 'family_id', 'n_type', 'status', 'created_at'],
      ),
      _TablePage(
        title: 'Аудит',
        future: _repo.auditLogs(),
        columns: const ['id', 'family_id', 'action', 'target_type', 'target_id', 'created_at'],
      ),
      _SettingsSection(onSignOut: () => _client?.auth.signOut()),
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
                            title: Text((row['display_name'] ?? '').toString()),
                            subtitle: Text('active: ${row['is_active']}'),
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
      columns: const ['id', 'family_id', 'plan_code', 'status', 'expires_at', 'source'],
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
                          title: Text('${row['code']} (${row['plan_code']})'),
                          subtitle: Text('used ${row['used_count']}/${row['max_uses']}'),
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
                                Text('child: ${row['child_id']}'),
                                Text('price: ${row['total_price']}'),
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
                                  '${row['child_last_name'] ?? ''} ${row['child_first_name'] ?? ''}',
                                ),
                                Text('family: ${row['family_id']}'),
                                Text('device: ${row['device_id']}'),
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
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<List<Map<String, dynamic>>> families() async =>
      _read('families', 'id, owner_user_id, family_code, clan_name');
  Future<List<Map<String, dynamic>>> profiles() async =>
      _read('profiles', 'user_id, family_id, role, display_name');
  Future<List<Map<String, dynamic>>> children() async =>
      _read('children', 'id, family_id, display_name, is_active');
  Future<List<Map<String, dynamic>>> quests() async =>
      _read('quests', 'id, family_id, title, status, quest_type, reward_amount');
  Future<List<Map<String, dynamic>>> products() async =>
      _read('shop_products', 'id, family_id, title, price, is_active');
  Future<List<Map<String, dynamic>>> purchases() async =>
      _read('shop_purchases', 'id, child_id, total_price, status');
  Future<List<Map<String, dynamic>>> subscriptions() async =>
      _read('family_subscriptions', 'id, family_id, plan_code, status, expires_at, source');
  Future<List<Map<String, dynamic>>> promocodes() async =>
      _read('promo_codes', 'id, code, plan_code, duration_days, max_uses, used_count, is_active');
  Future<List<Map<String, dynamic>>> payments() async =>
      _read('payment_orders', 'id, family_id, provider, amount_rub, status, plan_code');
  Future<List<Map<String, dynamic>>> notifications() async =>
      _read('notifications', 'id, family_id, n_type, status, created_at');
  Future<List<Map<String, dynamic>>> auditLogs() async =>
      _read('audit_logs', 'id, family_id, action, target_type, target_id, created_at');
  Future<List<Map<String, dynamic>>> pendingRequests() async =>
      _read('child_access_requests', 'id, family_id, child_first_name, child_last_name, device_id, status',
          filter: (q) => q.eq('status', 'pending'));

  Future<List<Map<String, dynamic>>> _read(
    String table,
    String fields, {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>> q,
    )? filter,
  }) async {
    final client = _client;
    if (client == null) return const [];
    var q = client.from(table).select(fields);
    if (filter != null) q = filter(q);
    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>).map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createPromoCode({
    required String code,
    required String planCode,
    required int durationDays,
    required int maxUses,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.from('promo_codes').insert({
      'code': code.toUpperCase(),
      'plan_code': planCode,
      'duration_days': durationDays,
      'max_uses': maxUses,
      'is_active': true,
    });
  }

  Future<void> approveRequest(String requestId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc('parent_approve_child_request', params: {'p_request_id': requestId});
  }

  Future<void> rejectRequest(String requestId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc('parent_reject_child_request', params: {'p_request_id': requestId});
  }

  Future<void> deactivateChild(String childId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc('parent_deactivate_child', params: {'p_child_id': childId});
  }

  Future<void> decidePurchase(String purchaseId, bool approve) async {
    final client = _client;
    if (client == null) return;
    await client.rpc('parent_decide_purchase', params: {
      'p_purchase_id': purchaseId,
      'p_approve': approve,
    });
  }
}

