import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../../home/child_soft_ui.dart';
import '../../wallet/wallet_repository.dart';
import '../quests_repository.dart';

class ChildQuestsPage extends ConsumerStatefulWidget {
  const ChildQuestsPage({super.key});

  @override
  ConsumerState<ChildQuestsPage> createState() => _ChildQuestsPageState();
}

class _ChildQuestsPageState extends ConsumerState<ChildQuestsPage> {
  Future<List<ChildQuestAssignmentItem>>? _future;
  int _tab = 0;

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final f = ref.read(questsRepositoryProvider).getChildAssignments(session.childId);
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
          ref.read(questsRepositoryProvider).getChildAssignments(session.childId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ChildQuestAssignmentItem>[];
        final personal = all
            .where((a) => a.distributionType != 'exchange')
            .toList();
        final exchange = all
            .where((a) => a.distributionType == 'exchange')
            .toList();
        final completed = all.where((a) => a.status == 'completed').length;

        final current = _tab == 0 ? personal : exchange;

        return ClanSectionPage(
          title: 'Биржа задач',
          onRefresh: _reload,
          onRefreshAsync: _reload,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _ChildQuestsHeroCard(completedCount: completed),
                  const SizedBox(height: 14),
                  _ChildQuestTabs(
                    personalCount: personal.length,
                    exchangeCount: exchange.length,
                    current: _tab,
                    onSelected: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 14),
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
                    ChildSoftCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 20),
                      child: Text(
                        _tab == 0
                            ? 'Личных задач пока нет'
                            : 'На бирже пока нет доступных задач',
                        style: const TextStyle(color: kChildInkMuted),
                      ),
                    ),
                  ...current.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ChildQuestCard(
                        item: item,
                        onChanged: _reload,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildQuestsHeroCard extends ConsumerWidget {
  const _ChildQuestsHeroCard({required this.completedCount});
  final int completedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName.trim()
        : 'Участник';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return FutureBuilder<WalletSummary?>(
      future: session == null
          ? Future.value(null)
          : ref.read(walletRepositoryProvider).getChildWallet(session.childId),
      builder: (context, walletSnap) {
        final balance = walletSnap.data?.balance ?? 0;
        return ChildSoftCard(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kBrandMint,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F4F1B),
                  ),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount ${_taskWord(completedCount)} выполнено',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kChildInkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '$balance',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: kChildBrandBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'задачи';
    return 'задач';
  }
}

class _ChildQuestTabs extends StatelessWidget {
  const _ChildQuestTabs({
    required this.personalCount,
    required this.exchangeCount,
    required this.current,
    required this.onSelected,
  });

  final int personalCount;
  final int exchangeCount;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChildQuestTabButton(
            selected: current == 0,
            count: personalCount,
            label: 'Мои задачи',
            onTap: () => onSelected(0),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ChildQuestTabButton(
            selected: current == 1,
            count: exchangeCount,
            label: 'Биржа',
            onTap: () => onSelected(1),
          ),
        ),
      ],
    );
  }
}

class _ChildQuestTabButton extends StatelessWidget {
  const _ChildQuestTabButton({
    required this.selected,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Active: mint background, dark green text
    // Inactive: white background, dark text, light shadow
    final bg = selected ? kBrandMint : Colors.white;
    final fg = selected ? const Color(0xFF1F4F1B) : kChildInk;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: selected
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildQuestCard extends ConsumerStatefulWidget {
  const _ChildQuestCard({
    required this.item,
    required this.onChanged,
  });

  final ChildQuestAssignmentItem item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ChildQuestCard> createState() => _ChildQuestCardState();
}

class _ChildQuestCardState extends ConsumerState<_ChildQuestCard> {
  final _picker = ImagePicker();
  bool _busy = false;
  bool _takenLocally = false;
  bool _submittedLocally = false;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.item.timeLimitMinutes != null &&
        (widget.item.status == 'assigned' || widget.item.status == 'in_progress')) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submittedLocally &&
      (_effectiveStatus == 'assigned' || _effectiveStatus == 'in_progress');
  bool get _canTake => _effectiveStatus == 'market';

  String get _effectiveStatus {
    if (_submittedLocally) return 'on_review';
    if (_takenLocally && widget.item.status == 'market') return 'in_progress';
    return widget.item.status;
  }

  Future<void> _takeQuest() async {
    if (_busy || !_canTake) return;
    setState(() => _busy = true);
    try {
      await ref.read(questsRepositoryProvider).takeFromMarket(widget.item.questId);
      if (!mounted) return;
      setState(() => _takenLocally = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Квест взят в работу')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
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
        photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
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
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markDoneFlow() async {
    if (_busy || !_canSubmit) return;
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

  String _statusLabel(String status) {
    return switch (status) {
      'assigned' => 'Назначено',
      'in_progress' => 'В работе',
      'market' => 'Биржа',
      'overdue' => 'Просрочено',
      'on_review' => 'На проверке',
      'submitted' => 'На проверке',
      _ => status,
    };
  }

  String? _remainingText() {
    final limit = widget.item.timeLimitMinutes;
    if (limit == null) return null;
    if (!(widget.item.status == 'assigned' || widget.item.status == 'in_progress')) return null;
    final finishAt = widget.item.createdAt.add(Duration(minutes: limit));
    final left = finishAt.difference(_now);
    if (left.inSeconds <= 0) return '00:00:00';
    final h = left.inHours.toString().padLeft(2, '0');
    final m = (left.inMinutes % 60).toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.item.dueAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(widget.item.dueAt!.toLocal())
        : 'Без дедлайна';

    final isOverdue = _effectiveStatus == 'overdue';
    final remaining = _remainingText();
    final statusColor = isOverdue
        ? const Color(0xFFD83A3A)
        : _effectiveStatus == 'on_review'
            ? kChildAccentOrange
            : kChildBrandBlue;

    return ChildSoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kChildInk,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _statusLabel(_effectiveStatus),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _QuestMetaText(
            icon: Icons.monetization_on,
            text: 'Награда: ${widget.item.rewardAmount} монет',
          ),
          _QuestMetaText(
            icon: Icons.swap_horiz,
            text:
                'Распределение: ${widget.item.distributionType == 'exchange' ? 'Биржа' : 'Адресно'}',
          ),
          if (widget.item.timeLimitMinutes != null)
            _QuestMetaText(
              icon: Icons.timer,
              text: 'Лимит: ${widget.item.timeLimitMinutes} мин',
            ),
          if (remaining != null)
            _QuestMetaText(
              icon: Icons.hourglass_bottom,
              text: 'Осталось: $remaining',
              color: remaining == '00:00:00'
                  ? const Color(0xFFD83A3A)
                  : null,
            ),
          _QuestMetaText(icon: Icons.event, text: 'Дедлайн: $due'),
          if ((widget.item.comment ?? '').trim().isNotEmpty)
            _QuestMetaText(
              icon: Icons.chat_bubble_outline,
              text: 'Комментарий: ${widget.item.comment}',
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _canTake
                ? FilledButton.icon(
                    onPressed: _busy ? null : _takeQuest,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_busy ? 'Подождите...' : 'Взять в работу'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kChildBrandBlue,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _busy || !_canSubmit ? null : _markDoneFlow,
                    icon: const Icon(Icons.check),
                    label: Text(_busy ? 'Отправка...' : 'Выполнено'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kChildBrandBlue,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestMetaText extends StatelessWidget {
  const _QuestMetaText({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? kChildInkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color ?? kChildInk,
                fontWeight: color != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
