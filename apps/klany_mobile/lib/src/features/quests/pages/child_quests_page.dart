import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../quests_repository.dart';

class ChildQuestsPage extends ConsumerStatefulWidget {
  const ChildQuestsPage({super.key});

  @override
  ConsumerState<ChildQuestsPage> createState() => _ChildQuestsPageState();
}

class _ChildQuestsPageState extends ConsumerState<ChildQuestsPage> {
  Future<List<ChildQuestAssignmentItem>>? _future;

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final f = ref.read(questsRepositoryProvider).getChildAssignments(session.childId);
    setState(() => _future = f);
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
    if (session == null) return const Center(child: Text('Сессия ребёнка не найдена'));

    return FutureBuilder<List<ChildQuestAssignmentItem>>(
      future: _future ?? ref.read(questsRepositoryProvider).getChildAssignments(session.childId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ChildQuestAssignmentItem>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
            const SliverAppBar(pinned: true, title: Text('Мои квесты')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(),
                    if (snapshot.hasError)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Ошибка: ${snapshot.error}'),
                        ),
                      ),
                    if (list.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                      const Text('Пока нет назначенных квестов'),
                    ...list.map(
                      (item) => _ChildQuestCard(
                        item: item,
                        onChanged: _reload,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      },
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
    final statusColor = isOverdue ? Colors.red : null;
    final remaining = _remainingText();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Статус: ${_statusLabel(_effectiveStatus)}',
              style: TextStyle(color: statusColor, fontWeight: isOverdue ? FontWeight.w700 : null),
            ),
            Text('Награда: ${widget.item.rewardAmount} монет'),
            Text('Распределение: ${widget.item.distributionType == 'exchange' ? 'Биржа' : 'Адресно'}'),
            if (widget.item.timeLimitMinutes != null) Text('Лимит: ${widget.item.timeLimitMinutes} мин'),
            if (remaining != null)
              Text(
                'Осталось: $remaining',
                style: TextStyle(
                  color: remaining == '00:00:00' ? Colors.red : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text('Дедлайн: $due'),
            if ((widget.item.comment ?? '').trim().isNotEmpty)
              Text('Комментарий: ${widget.item.comment}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _canTake
                  ? FilledButton.icon(
                      onPressed: _busy ? null : _takeQuest,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_busy ? 'Подождите...' : 'Взять в работу'),
                    )
                  : FilledButton.icon(
                      onPressed: _busy || !_canSubmit ? null : _markDoneFlow,
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Отправка...' : 'Выполнено'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

