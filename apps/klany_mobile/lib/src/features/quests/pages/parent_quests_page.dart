import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/wallet_repository.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../quests_repository.dart';

// ─── Main Exchange Page ───────────────────────────────────────────────────────

class ParentQuestsPage extends ConsumerStatefulWidget {
  const ParentQuestsPage({super.key});

  @override
  ConsumerState<ParentQuestsPage> createState() => _ParentQuestsPageState();
}

class _ParentQuestsPageState extends ConsumerState<ParentQuestsPage> {
  int _tab = 0;
  int _selectedWallet = -1;
  bool _questsExpanded = false;
  int _rublesPer10Coins = 100;
  List<ParentChildWalletItem> _wallets = const [];
  List<ParentMemberItem> _parents = const [];

  bool _walletsListenerSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_walletsListenerSet) {
      _walletsListenerSet = true;
      ref.listenManual<AsyncValue<ParentFamilyContext?>>(
        parentFamilyContextProvider,
        (prev, next) {
          if (next.asData?.value != null) {
            _loadWallets();
          }
        },
        fireImmediately: true,
      );
    }
  }

  void _toggleQuests() => setState(() => _questsExpanded = !_questsExpanded);

  Future<void> _loadWallets() async {
    final family = ref.read(parentFamilyContextProvider).asData?.value;
    if (family == null) return;
    try {
      final wallets = await ref
          .read(walletRepositoryProvider)
          .getFamilyWallets(family.familyId);
      final parents = await ref
          .read(parentAccessRepositoryProvider)
          .getParentMembers(family.familyId);
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _parents = parents;
      });
    } catch (_) {}
  }

  Future<void> _showAdjustDialog(ParentChildWalletItem wallet) async {
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Корректировка: ${wallet.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: 'Сумма (+/-)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(hintText: 'Комментарий'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim());
    if (amount == null || amount == 0) return;
    try {
      await ref.read(walletRepositoryProvider).adjustWallet(
            childId: wallet.childId,
            amount: amount,
            note: commentCtrl.text.trim(),
          );
      await _loadWallets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _editCoinRate() async {
    final ctrl = TextEditingController(text: _rublesPer10Coins.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Курс монет'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '10 монет = ? рублей'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final rate = int.tryParse(ctrl.text.trim());
    if (rate != null && rate > 0) setState(() => _rublesPer10Coins = rate);
  }

  String _formatBalance(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(parentFamilyContextProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (family) {
            if (family == null) {
              return const Center(child: Text('Семья не найдена'));
            }
            return _buildPage(family);
          },
        );
  }

  Widget _buildQuestsHeader() {
    return GestureDetector(
      onTap: _toggleQuests,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        color: kChildSurfaceSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              _questsExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: kChildInkMuted,
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'БИРЖА ЗАДАЧ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kChildInkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Активные, создание, проверка',
                  style: TextStyle(fontSize: 11, color: kChildInkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(ParentFamilyContext family) {
    final sel = _selectedWallet >= 0 && _selectedWallet < _wallets.length
        ? _wallets[_selectedWallet]
        : null;

    final questPages = <Widget>[
      _QuestsList(familyId: family.familyId),
      _QuestCreateForm(familyId: family.familyId),
      _QuestReviewList(familyId: family.familyId),
    ];

    return Scaffold(
      backgroundColor: kBgCloud,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: kChildInk),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  centerTitle: true,
                  title: const Text(
                    'Создать задачу',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                ),
                body: _QuestCreateForm(familyId: family.familyId),
              ),
            ),
          ),
          backgroundColor: kChildBrandBlue,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      body: CloudBackground(
        child: SafeArea(
        bottom: false,
        child: Column(
          children: [
              Expanded(
                child: ListView(
                  children: [
                    // ── "Экономика" header ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Экономика',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: kChildInk,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            child: InkWell(
                              onTap: _loadWallets,
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.refresh,
                                  color: kChildInk,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ParentShopPage(),
                                ),
                              ),
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: kChildInk,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Members selector ───────────────────────────────
                    SizedBox(
                      height: 116,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _WalletChip(
                            label: 'Все',
                            icon: Icons.person_outline,
                            selected: _selectedWallet == -1,
                            onTap: () =>
                                setState(() => _selectedWallet = -1),
                          ),
                          // Родители
                          ..._parents.map((p) {
                            final name = p.displayName.trim().isEmpty
                                ? 'Родитель'
                                : p.displayName.trim();
                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _WalletChip(
                                label: name,
                                userKey: 'parent:${p.userId}',
                                selected: false,
                                onTap: () {},
                              ),
                            );
                          }),
                          // Дети
                          ..._wallets.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _WalletChip(
                                label: e.value.displayName.trim().isEmpty
                                    ? '—'
                                    : e.value.displayName.trim(),
                                userKey: 'child:${e.value.childId}',
                                selected: _selectedWallet == e.key,
                                onTap: () => setState(
                                  () => _selectedWallet = e.key,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Big balance ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: _CoinStackIcon(),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatBalance(sel?.balance ?? _wallets.fold<int>(0, (a, w) => a + w.balance)),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: kChildBrandBlue,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(sel?.balance ?? _wallets.fold<int>(0, (a, w) => a + w.balance)) * _rublesPer10Coins ~/ 10} ₽',
                            style: const TextStyle(
                              fontSize: 14,
                              color: kChildInkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Управление монетами card ───────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Управление\nмонетами',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: kChildInk,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                _CircleIconBtn(
                                  icon: Icons.add,
                                  onTap: () => sel != null
                                      ? _showAdjustDialog(sel)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                _CircleIconBtn(
                                  icon: Icons.remove,
                                  onTap: () => sel != null
                                      ? _showAdjustDialog(sel)
                                      : null,
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1, color: kChildOutline),
                            ),
                            InkWell(
                              onTap: _editCoinRate,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Курс',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: kChildInk,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '10 монет = $_rublesPer10Coins ₽',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: kChildInkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: kChildInkMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Биржа задач section (always visible) ──────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Text(
                        'Биржа задач',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PillTab(
                              label: 'Активные',
                              selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _PillTab(
                              label: 'Проверка',
                              selected: _tab == 2,
                              onTap: () => setState(() => _tab = 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _tab == 2 ? 'На проверке' : 'Все задачи',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kChildInkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // List rendered inline
                    if (_tab == 0)
                      _QuestsList(familyId: family.familyId)
                    else
                      _QuestReviewList(familyId: family.familyId),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? kBrandMint : Colors.white;
    final fg = selected ? const Color(0xFF1F4F1B) : kChildInk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: selected
              ? null
              : Border.all(color: kChildOutline, width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _WalletChip extends StatelessWidget {
  const _WalletChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.emoji,
    this.userKey,
  });
  final String label;
  final String? userKey;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  static String _avatarAssetForName(String name) {
    final idx = (name.hashCode.abs() % 9) + 1;
    return 'assets/figma/avatar_$idx.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kChildBrandBlue.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2F8),
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: kChildBrandBlue, width: 2)
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, color: kChildInk, size: 28)
                  : (userKey != null
                      ? UserAvatar(
                          userKey: userKey!,
                          size: 56,
                          fallbackText:
                              emoji ?? label.characters.first.toUpperCase(),
                        )
                      : Image.asset(
                          _avatarAssetForName(label),
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Text(
                            emoji ?? label.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 22),
                          ),
                        )),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: kChildInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustBtn extends StatelessWidget {
  const _AdjustBtn({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF7B6FD0) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: kChildOutline, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: filled ? Colors.white : kChildInkMuted,
          ),
        ),
      ),
    );
  }
}

class _QuestTab extends StatelessWidget {
  const _QuestTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2E3A4E) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quests list ──────────────────────────────────────────────────────────────

class _QuestsList extends ConsumerStatefulWidget {
  const _QuestsList({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_QuestsList> createState() => _QuestsListState();
}

class _QuestsListState extends ConsumerState<_QuestsList> {
  Future<List<ParentQuestItem>>? _future;

  void _reload() {
    setState(() {
      _future =
          ref.read(questsRepositoryProvider).getParentQuests(widget.familyId);
    });
  }

  Future<void> _editQuest(ParentQuestItem q) async {
    final repo = ref.read(questsRepositoryProvider);
    final children = await repo.getFamilyChildren(widget.familyId);
    if (!mounted) return;

    final titleCtl = TextEditingController(text: q.title);
    final descriptionCtl = TextEditingController(text: q.description);
    final rewardCtl =
        TextEditingController(text: q.rewardAmount.toString());
    final hoursCtl = TextEditingController(
      text: ((q.timeLimitMinutes ?? 0) ~/ 60).toString(),
    );
    final minutesCtl = TextEditingController(
      text: ((q.timeLimitMinutes ?? 0) % 60).toString(),
    );
    final statuses = <String>['active', 'closed', 'archived'];
    var status = q.status.isEmpty ? 'active' : q.status;
    if (!statuses.contains(status)) statuses.add(status);
    var type = q.questType.isEmpty ? 'one_time' : q.questType;
    var distributionType =
        q.distributionType == 'exchange' ? 'exchange' : 'assigned';
    var autoApprove = q.autoApprove;
    var hasTimeLimit = q.timeLimitMinutes != null;
    var scheduleType = q.scheduleType == 'daily' ||
            q.scheduleType == 'weekly' ||
            q.scheduleType == 'custom_days'
        ? q.scheduleType
        : (type == 'recurring' ? 'daily' : 'none');
    final scheduleDays = <String>{...q.scheduleDays};
    final selectedChildren = <String>{...q.childIds};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Редактировать квест'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'recurring',
                        child: Text('Повторяющаяся'),
                      ),
                      DropdownMenuItem(
                        value: 'one_time',
                        child: Text('Разовая'),
                      ),
                      DropdownMenuItem(
                        value: 'unique',
                        child: Text('Уникальная'),
                      ),
                    ],
                    onChanged: (v) {
                      setLocalState(() {
                        type = v ?? 'one_time';
                        if (type != 'recurring') {
                          scheduleType = 'none';
                          scheduleDays.clear();
                        } else if (scheduleType == 'none') {
                          scheduleType = 'daily';
                        }
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Тип'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rewardCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Награда'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Статус'),
                    items: statuses
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: distributionType,
                    items: const [
                      DropdownMenuItem(
                        value: 'assigned',
                        child: Text('Адресное назначение'),
                      ),
                      DropdownMenuItem(
                        value: 'exchange',
                        child: Text('Биржа задач'),
                      ),
                    ],
                    onChanged: (v) =>
                        setLocalState(() => distributionType = v ?? 'assigned'),
                    decoration: const InputDecoration(
                      labelText: 'Распределение',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: autoApprove,
                    onChanged: (v) => setLocalState(() => autoApprove = v),
                    title: const Text('Автоподтверждение'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: hasTimeLimit,
                    onChanged: (v) =>
                        setLocalState(() => hasTimeLimit = v == true),
                    title: const Text('Лимит времени'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasTimeLimit)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursCtl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Часы'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: minutesCtl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Минуты'),
                          ),
                        ),
                      ],
                    ),
                  if (type == 'recurring') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          scheduleType == 'none' ? 'daily' : scheduleType,
                      items: const [
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Ежедневно'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Еженедельно'),
                        ),
                        DropdownMenuItem(
                          value: 'custom_days',
                          child: Text('По выбранным дням'),
                        ),
                      ],
                      onChanged: (v) =>
                          setLocalState(() => scheduleType = v ?? 'daily'),
                      decoration: const InputDecoration(
                        labelText: 'График повторения',
                      ),
                    ),
                    if (scheduleType == 'custom_days') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          ('mon', 'Пн'),
                          ('tue', 'Вт'),
                          ('wed', 'Ср'),
                          ('thu', 'Чт'),
                          ('fri', 'Пт'),
                          ('sat', 'Сб'),
                          ('sun', 'Вс'),
                        ]
                            .map(
                              (d) => FilterChip(
                                label: Text(d.$2),
                                selected: scheduleDays.contains(d.$1),
                                onSelected: (selected) {
                                  setLocalState(() {
                                    if (selected) {
                                      scheduleDays.add(d.$1);
                                    } else {
                                      scheduleDays.remove(d.$1);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  if (distributionType == 'exchange')
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront),
                      title: Text('Задача будет опубликована на Бирже'),
                    ),
                  if (distributionType == 'assigned')
                    ...children.map(
                      (child) => CheckboxListTile(
                        value: selectedChildren.contains(child.id),
                        title: Text(child.displayName),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setLocalState(() {
                            if (v == true) {
                              selectedChildren.add(child.id);
                            } else {
                              selectedChildren.remove(child.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final reward = int.tryParse(rewardCtl.text.trim());
    if (reward == null || reward < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Награда должна быть >= 0')),
      );
      return;
    }
    final totalMinutes =
        (int.tryParse(hoursCtl.text.trim()) ?? 0) * 60 +
        (int.tryParse(minutesCtl.text.trim()) ?? 0);
    if (hasTimeLimit && totalMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите лимит времени больше 0')),
      );
      return;
    }
    if (distributionType == 'assigned' && selectedChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного ребёнка')),
      );
      return;
    }
    if (type == 'recurring' &&
        scheduleType == 'custom_days' &&
        scheduleDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день повторения')),
      );
      return;
    }
    await repo.updateQuest(
      questId: q.id,
      title: titleCtl.text.trim(),
      description: descriptionCtl.text.trim(),
      rewardAmount: reward,
      questType: type,
      status: status,
      childIds: distributionType == 'assigned'
          ? selectedChildren.toList()
          : const <String>[],
      distributionType: distributionType,
      autoApprove: autoApprove,
      timeLimitMinutes: hasTimeLimit ? totalMinutes : null,
      scheduleType: type == 'recurring' ? scheduleType : 'none',
      scheduleDays: type == 'recurring'
          ? scheduleDays.toList()
          : const <String>[],
    );
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Квест обновлён')));
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel(String v) => switch (v) {
          'recurring' => 'Повторяющаяся',
          'unique' => 'Уникальная',
          _ => 'Разовая',
        };

    return FutureBuilder<List<ParentQuestItem>>(
      future: _future ??
          ref.read(questsRepositoryProvider).getParentQuests(widget.familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentQuestItem>[];
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Все задачи',
                    style: TextStyle(fontSize: 14, color: kChildInkMuted),
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, color: kChildInkMuted, size: 20),
                ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (snapshot.hasError)
              Text('Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            if (list.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Нет задач',
                    style: TextStyle(color: kChildInkMuted),
                  ),
                ),
              ),
            ...list.asMap().entries.map(
              (e) {
                final q = e.value;
                final colors = [kBrandMint, kBrandLavender, kBrandSky, kBrandSunny];
                final cardColor = colors[e.key % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChildSoftCard(
                    color: cardColor,
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kChildInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${q.rewardAmount} монет',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: kChildInkMuted,
                                ),
                              ),
                              Text(
                                '${typeLabel(q.questType)} • ${q.distributionType == 'exchange' ? 'Биржа' : 'Адресно'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kChildInkMuted,
                                ),
                              ),
                              Text(
                                '${q.status} • ${DateFormat('dd.MM HH:mm').format(q.createdAt.toLocal())}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kChildInkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editQuest(q);
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить квест'),
                            content: const Text('Удалить квест полностью?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(questsRepositoryProvider)
                              .deleteQuest(q.id);
                          if (!context.mounted) return;
                          _reload();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Квест удалён')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить'),
                      ),
                    ],
                  ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── Quest create form ────────────────────────────────────────────────────────

class _QuestCreateForm extends ConsumerStatefulWidget {
  const _QuestCreateForm({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_QuestCreateForm> createState() => _QuestCreateFormState();
}

class _QuestCreateFormState extends ConsumerState<_QuestCreateForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController(text: '10');
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();
  String _type = 'one_time';
  String _distributionType = 'assigned';
  bool _autoApprove = false;
  bool _hasTimeLimit = false;
  String _scheduleType = 'none';
  bool _usePreset = true;
  String _preset = 'custom';
  final Set<String> _scheduleDays = {};
  final Set<String> _selectedChildren = {};
  bool _busy = false;

  static const Map<String, List<String>> _presets = {
    'recurring': [
      'Встать с кровати',
      'Заправить кровать',
      'Почистить зубы',
      'Умыться',
      'Сделать зарядку',
      'Выпить стакан воды',
      'Выгулять собаку',
      'Насыпать корм питомцу',
      'Собрать рюкзак',
      'Сдать телефон родителям',
      'Вынести мусор',
      'Вымыть свою посуду',
      'Сделать уроки',
      'Занятие музыкой',
    ],
    'one_time': [
      'Сходить в магазин',
      'Помыть посуду',
      'Почистить обувь',
      'Провести влажную уборку',
      'Пропылесосить',
      'Приготовить еду',
    ],
    'unique': [
      'Прочитать 10 страниц',
      'Выучить 5 иностранных слов',
      'Исправить оценку',
      'Хорошо выступить на соревнованиях',
    ],
  };

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reward.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  List<String> get _presetItems => ['custom', ...(_presets[_type] ?? [])];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyChildLite>>(
      future: ref
          .read(questsRepositoryProvider)
          .getFamilyChildren(widget.familyId),
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <FamilyChildLite>[];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: CircularProgressIndicator(),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: const [
                    DropdownMenuItem(
                      value: 'recurring',
                      child: Text('Повторяющаяся'),
                    ),
                    DropdownMenuItem(
                      value: 'one_time',
                      child: Text('Разовая'),
                    ),
                    DropdownMenuItem(
                      value: 'unique',
                      child: Text('Уникальная'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v ?? 'one_time';
                    _preset = 'custom';
                    _title.clear();
                    _scheduleType =
                        _type == 'recurring' ? 'daily' : 'none';
                    _scheduleDays.clear();
                  }),
                  decoration: const InputDecoration(labelText: 'Тип'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _usePreset,
                  onChanged: (v) => setState(() {
                    _usePreset = v == true;
                    _preset = 'custom';
                    _title.clear();
                  }),
                  title: const Text('Выбрать из базового списка'),
                  subtitle: const Text('Снимите, если нужна своя задача'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                if (_usePreset)
                  DropdownButtonFormField<String>(
                    initialValue: _preset,
                    items: _presetItems
                        .map(
                          (title) => DropdownMenuItem<String>(
                            value: title,
                            child: Text(
                              title == 'custom' ? 'Свободная задача' : title,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _preset = v ?? 'custom';
                      if (_preset != 'custom') _title.text = _preset;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Выбор задачи',
                      prefixIcon: Icon(Icons.playlist_add_check),
                    ),
                  ),
                if (!_usePreset || _preset == 'custom')
                  TextFormField(
                    controller: _title,
                    decoration:
                        const InputDecoration(labelText: 'Название'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Введите название' : null,
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _distributionType,
                  items: const [
                    DropdownMenuItem(
                      value: 'assigned',
                      child: Text('Адресное назначение'),
                    ),
                    DropdownMenuItem(
                      value: 'exchange',
                      child: Text('Биржа задач'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _distributionType = v ?? 'assigned'),
                  decoration:
                      const InputDecoration(labelText: 'Распределение'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _autoApprove,
                  onChanged: (v) => setState(() => _autoApprove = v),
                  title: const Text('Автоподтверждение'),
                  subtitle:
                      const Text('Награда зачисляется сразу после выполнения'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _hasTimeLimit,
                  onChanged: (v) =>
                      setState(() => _hasTimeLimit = v == true),
                  title: const Text('Лимит времени'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_hasTimeLimit)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hours,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Часы'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _minutes,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Минуты'),
                        ),
                      ),
                    ],
                  ),
                if (_type == 'recurring') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _scheduleType,
                    items: const [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('Ежедневно'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Еженедельно'),
                      ),
                      DropdownMenuItem(
                        value: 'custom_days',
                        child: Text('По выбранным дням'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _scheduleType = v ?? 'daily'),
                    decoration:
                        const InputDecoration(labelText: 'График повторения'),
                  ),
                  if (_scheduleType == 'custom_days') ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ('mon', 'Пн'),
                        ('tue', 'Вт'),
                        ('wed', 'Ср'),
                        ('thu', 'Чт'),
                        ('fri', 'Пт'),
                        ('sat', 'Сб'),
                        ('sun', 'Вс'),
                      ]
                          .map(
                            (d) => FilterChip(
                              label: Text(d.$2),
                              selected: _scheduleDays.contains(d.$1),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _scheduleDays.add(d.$1);
                                  } else {
                                    _scheduleDays.remove(d.$1);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reward,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Награда (монеты)'),
                  validator: (v) {
                    final value = int.tryParse((v ?? '').trim());
                    if (value == null || value < 0) return 'Укажите число >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Исполнители',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                if (_distributionType == 'exchange')
                  const ListTile(
                    leading: Icon(Icons.storefront),
                    title: Text('Задача будет опубликована на Бирже'),
                    subtitle: Text('Любой ребёнок сможет взять её в работу'),
                  ),
                if (_distributionType == 'assigned')
                  ...children.map(
                    (child) => CheckboxListTile(
                      value: _selectedChildren.contains(child.id),
                      title: Text(child.displayName),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedChildren.add(child.id);
                          } else {
                            _selectedChildren.remove(child.id);
                          }
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            final messenger = ScaffoldMessenger.of(context);
                            if (_distributionType == 'assigned' &&
                                _selectedChildren.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Выберите хотя бы одного ребёнка'),
                                ),
                              );
                              return;
                            }
                            final hours =
                                int.tryParse(_hours.text.trim()) ?? 0;
                            final minutes =
                                int.tryParse(_minutes.text.trim()) ?? 0;
                            final totalMinutes = hours * 60 + minutes;
                            if (_hasTimeLimit && totalMinutes <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Укажите лимит времени больше 0',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (_type == 'recurring' &&
                                _scheduleType == 'custom_days' &&
                                _scheduleDays.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Выберите хотя бы один день повторения',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => _busy = true);
                            try {
                              await ref
                                  .read(questsRepositoryProvider)
                                  .createQuest(
                                    title: _title.text,
                                    description: _description.text,
                                    rewardAmount:
                                        int.parse(_reward.text.trim()),
                                    questType: _type,
                                    dueAt: null,
                                    childIds:
                                        _distributionType == 'assigned'
                                            ? _selectedChildren.toList()
                                            : const [],
                                    distributionType: _distributionType,
                                    autoApprove: _autoApprove,
                                    timeLimitMinutes: _hasTimeLimit
                                        ? totalMinutes
                                        : null,
                                    scheduleType: _type == 'recurring'
                                        ? _scheduleType
                                        : 'none',
                                    scheduleDays: _type == 'recurring'
                                        ? _scheduleDays.toList()
                                        : const [],
                                  );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Квест создан')),
                              );
                              _title.clear();
                              _description.clear();
                              _reward.text = '10';
                              _hours.text = '0';
                              _minutes.text = '0';
                              setState(() {
                                _selectedChildren.clear();
                                _scheduleDays.clear();
                                _preset = 'custom';
                                _usePreset = true;
                                _distributionType = 'assigned';
                                _autoApprove = false;
                                _hasTimeLimit = false;
                                _type = 'one_time';
                                _scheduleType = 'none';
                              });
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка создания: $e'),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Создать квест'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Quest review list ────────────────────────────────────────────────────────

class _QuestReviewList extends ConsumerWidget {
  const _QuestReviewList({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ParentReviewItem>>(
      future:
          ref.read(questsRepositoryProvider).getSubmittedForReview(familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentReviewItem>[];
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (snapshot.hasError)
              Text('Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            if (list.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Нет заявок на проверку',
                    style: TextStyle(color: kChildInkMuted),
                  ),
                ),
              ),
            ...list.map((item) => _ReviewCard(item: item)),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.item});
  final ParentReviewItem item;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _review(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(questsRepositoryProvider).reviewSubmission(
            questId: widget.item.questId,
            childId: widget.item.childId,
            approve: approve,
            comment: _comment.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(approve ? 'Задание подтверждено' : 'Задание отклонено'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка проверки: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Исполнитель: ${widget.item.childName}'),
            if (widget.item.submittedAt != null)
              Text(
                'Отправлено: ${DateFormat('dd.MM HH:mm').format(widget.item.submittedAt!.toLocal())}',
              ),
            if ((widget.item.evidencePath ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: (widget.item.evidenceUrl ?? '').isNotEmpty
                        ? Image.network(
                            widget.item.evidenceUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, err, st) => Center(
                              child: Text('Фото: ${widget.item.evidencePath}'),
                            ),
                          )
                        : Center(
                            child: Text('Фото: ${widget.item.evidencePath}'),
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _review(false),
                    child: const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _review(true),
                    child: const Text('Подтвердить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: kChildOutline, width: 1.4)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: kChildInk, size: 22),
        ),
      ),
    );
  }
}

class _CoinStackIcon extends StatelessWidget {
  const _CoinStackIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CoinStackPainter(),
    );
  }
}

class _CoinStackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = kChildBrandBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final coinW = w * 0.95;
    final coinH = h * 0.30;
    final cx = w / 2;
    // Draw 3 stacked coins (ellipses with side walls), bottom to top
    for (int i = 0; i < 3; i++) {
      final cy = h - coinH / 2 - i * (coinH * 0.85);
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: coinW, height: coinH);
      canvas.drawOval(rect, stroke);
      // side walls (only between coins or for bottom)
      final leftX = cx - coinW / 2;
      final rightX = cx + coinW / 2;
      final wallTop = cy;
      final wallBottom = cy + coinH * 0.45;
      canvas.drawLine(Offset(leftX, wallTop), Offset(leftX, wallBottom), stroke);
      canvas.drawLine(Offset(rightX, wallTop), Offset(rightX, wallBottom), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
