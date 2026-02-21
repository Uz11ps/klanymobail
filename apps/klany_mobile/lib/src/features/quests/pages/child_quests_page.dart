import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../quests_repository.dart';

class ChildQuestsPage extends ConsumerWidget {
  const ChildQuestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) return const Center(child: Text('Сессия ребёнка не найдена'));

    return FutureBuilder<List<ChildQuestAssignmentItem>>(
      future: ref.read(questsRepositoryProvider).getChildAssignments(session.childId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ChildQuestAssignmentItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Мои квесты')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(),
                    if (list.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                      const Text('Пока нет назначенных квестов'),
                    ...list.map(
                      (item) => _ChildQuestCard(item: item),
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

class _ChildQuestCard extends ConsumerStatefulWidget {
  const _ChildQuestCard({required this.item});

  final ChildQuestAssignmentItem item;

  @override
  ConsumerState<_ChildQuestCard> createState() => _ChildQuestCardState();
}

class _ChildQuestCardState extends ConsumerState<_ChildQuestCard> {
  final _picker = ImagePicker();
  bool _busy = false;

  bool get _canSubmit =>
      widget.item.status == 'assigned' || widget.item.status == 'in_progress';

  Future<void> _submitWithPhoto() async {
    if (_busy || !_canSubmit) return;
    setState(() => _busy = true);
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
      await ref.read(questsRepositoryProvider).submitQuestWithEvidence(
            questId: widget.item.questId,
            evidenceFile: photo,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отправлено на проверку')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.item.dueAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(widget.item.dueAt!.toLocal())
        : 'Без дедлайна';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Статус: ${widget.item.status}'),
            Text('Награда: ${widget.item.rewardAmount} монет'),
            Text('Дедлайн: $due'),
            if ((widget.item.comment ?? '').trim().isNotEmpty)
              Text('Комментарий: ${widget.item.comment}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || !_canSubmit ? null : _submitWithPhoto,
                icon: const Icon(Icons.upload),
                label: Text(_busy ? 'Отправка...' : 'Отправить фото-отчёт'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

