import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/child_session.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../wallet/pages/child_wallet_page.dart';
import '../../wallet/wallet_repository.dart';
import '../quests_repository.dart';

const _cardColors = <Color>[kBrandMint, kBrandLavender, kBrandSky];

class ChildQuestsPage extends ConsumerStatefulWidget {
  const ChildQuestsPage({super.key});

  @override
  ConsumerState<ChildQuestsPage> createState() => _ChildQuestsPageState();
}

class _ChildQuestsPageState extends ConsumerState<ChildQuestsPage> {
  Future<List<ChildQuestAssignmentItem>>? _future;
  int _tab = 0; // 0 = Мои задачи, 1 = Биржа

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final f = ref
        .read(questsRepositoryProvider)
        .getChildAssignments(session.childId);
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: Text('Сессия ребёнка не найдена'));
    }

    return FutureBuilder<List<ChildQuestAssignmentItem>>(
      future: _future ??
          ref
              .read(questsRepositoryProvider)
              .getChildAssignments(session.childId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ChildQuestAssignmentItem>[];
        final personal =
            all.where((a) => a.distributionType != 'exchange').toList();
        final exchange =
            all.where((a) => a.distributionType == 'exchange').toList();
        final completed = all.where((a) => a.status == 'completed').length;
        final current = _tab == 0 ? personal : exchange;

        return Container(
          color: kBgCloud,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _tab == 0 ? 'Мои задачи' : 'Биржа задач',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
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
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        child: InkWell(
                          onTap: _reload,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.refresh_rounded,
                              color: kChildInk,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ChildProfileCard(completedCount: completed),
                  const SizedBox(height: 18),
                  Container(height: 1, color: kChildOutline),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ChildStatTile(
                          label: 'Мои задачи',
                          count: personal.length,
                          selected: _tab == 0,
                          selectedColor: kBrandMint,
                          onTap: () => setState(() => _tab = 0),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ChildStatTile(
                          label: 'Биржа',
                          count: exchange.length,
                          selected: _tab == 1,
                          selectedColor: kBrandLavender,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (snapshot.hasError)
                    ChildSoftCard(
                      child: Text('Ошибка: ${snapshot.error}'),
                    ),
                  if (!snapshot.hasError &&
                      snapshot.connectionState != ConnectionState.waiting &&
                      current.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          _tab == 0
                              ? 'Личных задач пока нет'
                              : 'На бирже пока нет доступных задач',
                          style: const TextStyle(color: kChildInkMuted),
                        ),
                      ),
                    ),
                  ...current.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ChildQuestCard(
                            item: e.value,
                            bg: _cardColors[e.key % _cardColors.length],
                            isExchange: _tab == 1,
                            onChanged: _reload,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChildProfileCard extends ConsumerWidget {
  const _ChildProfileCard({required this.completedCount});
  final int completedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName.trim()
        : 'Участник';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final userKey = session != null ? 'child:${session.childId}' : 'child:guest';

    return FutureBuilder<WalletSummary?>(
      future: session == null
          ? Future.value(null)
          : ref.read(walletRepositoryProvider).getChildWallet(session.childId),
      builder: (context, walletSnap) {
        final balance = walletSnap.data?.balance ?? 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChildWalletPage()),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: UserAvatar(
                      userKey: userKey,
                      size: 60,
                      fallbackText: initial,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: kChildInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completedCount ${_taskWord(completedCount)} выполнено',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kChildInkMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF2F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoinStackIcon(size: 18),
                              const SizedBox(width: 6),
                              Text(
                                _formatBalance(balance),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: kChildBrandBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatBalance(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'задачи';
    return 'задач';
  }
}

class _ChildStatTile extends StatelessWidget {
  const _ChildStatTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedColor : Colors.white;
    final fg = selected ? const Color(0xFF000000) : kChildInkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? null
                : Border.all(color: kChildOutline, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF000000) : kChildInk,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildQuestCard extends ConsumerStatefulWidget {
  const _ChildQuestCard({
    required this.item,
    required this.bg,
    required this.isExchange,
    required this.onChanged,
  });

  final ChildQuestAssignmentItem item;
  final Color bg;
  final bool isExchange;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ChildQuestCard> createState() => _ChildQuestCardState();
}

class _ChildQuestCardState extends ConsumerState<_ChildQuestCard> {
  final _picker = ImagePicker();
  bool _busy = false;
  bool _takenLocally = false;
  bool _submittedLocally = false;

  String get _effectiveStatus {
    if (_submittedLocally) return 'on_review';
    if (_takenLocally && widget.item.status == 'market') return 'in_progress';
    return widget.item.status;
  }

  bool get _canTake => _effectiveStatus == 'market';
  bool get _canSubmit =>
      !_submittedLocally &&
      (_effectiveStatus == 'assigned' || _effectiveStatus == 'in_progress');

  Future<void> _takeQuest() async {
    if (_busy || !_canTake) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(questsRepositoryProvider)
          .takeFromMarket(widget.item.questId);
      if (!mounted) return;
      setState(() => _takenLocally = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Квест взят в работу')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitDone({required bool withPhoto}) async {
    if (_busy || !_canSubmit) return;
    setState(() => _busy = true);
    try {
      XFile? photo;
      if (withPhoto) {
        photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
        );
      }
      await ref.read(questsRepositoryProvider).submitQuestWithEvidence(
            questId: widget.item.questId,
            evidenceFile: photo,
          );
      if (!mounted) return;
      setState(() => _submittedLocally = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отправлено на проверку')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFlow() async {
    if (widget.isExchange && _canTake) {
      await _takeQuest();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Выполнено без фото'),
              onTap: () => Navigator.of(ctx).pop('no_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo),
              title: const Text('Выполнено + фото'),
              onTap: () => Navigator.of(ctx).pop('with_photo'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _submitDone(withPhoto: choice == 'with_photo');
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.item.rewardAmount;
    final photoLabel =
        widget.item.autoApprove ? 'Без фото-отчёта' : 'Фото-отчёт';
    final days = _daysLabel(widget.item);
    final btnLabel = widget.isExchange ? 'Взять с биржи' : 'Открыть';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: widget.bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kChildInk,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '+$reward монет',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kChildInk,
            ),
          ),
          Text(
            photoLabel,
            style: const TextStyle(fontSize: 14, color: kChildInk),
          ),
          Text(
            days,
            style: const TextStyle(fontSize: 14, color: kChildInk),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _busy ? null : _openFlow,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  _busy ? 'Подождите…' : btnLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kChildInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _daysLabel(ChildQuestAssignmentItem q) {
    if (q.dueAt == null) return 'Без дедлайна';
    final left = q.dueAt!.difference(DateTime.now()).inDays;
    if (left <= 0) return 'Срочно';
    final mod10 = left % 10;
    final mod100 = left % 100;
    String word;
    if (mod10 == 1 && mod100 != 11) {
      word = 'день';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      word = 'дня';
    } else {
      word = 'дней';
    }
    return '$left $word';
  }
}
