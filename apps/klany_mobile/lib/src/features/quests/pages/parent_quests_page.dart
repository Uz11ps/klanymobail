import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../quests_repository.dart';

class ParentQuestsPage extends ConsumerStatefulWidget {
  const ParentQuestsPage({super.key});

  @override
  ConsumerState<ParentQuestsPage> createState() => _ParentQuestsPageState();
}

class _ParentQuestsPageState extends ConsumerState<ParentQuestsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));

        final pages = <Widget>[
          _ParentQuestsList(familyId: family.familyId),
          _ParentQuestCreateForm(familyId: family.familyId),
          _ParentQuestReviewList(familyId: family.familyId),
        ];

        return Scaffold(
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (v) => setState(() => _tab = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.list), label: 'Активные'),
              NavigationDestination(icon: Icon(Icons.add_task), label: 'Создать'),
              NavigationDestination(icon: Icon(Icons.fact_check), label: 'Проверка'),
            ],
          ),
        );
      },
    );
  }
}

class _ParentQuestsList extends ConsumerWidget {
  const _ParentQuestsList({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ParentQuestItem>>(
      future: ref.read(questsRepositoryProvider).getParentQuests(familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentQuestItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Квесты')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(),
                    if (!snapshot.hasData && snapshot.connectionState != ConnectionState.waiting)
                      const Text('Нет данных'),
                    ...list.map(
                      (q) => Card(
                        child: ListTile(
                          title: Text(q.title),
                          subtitle: Text(
                            '${q.questType} • ${q.status} • ${q.rewardAmount} монет • ${DateFormat('dd.MM HH:mm').format(q.createdAt.toLocal())}',
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

class _ParentQuestCreateForm extends ConsumerStatefulWidget {
  const _ParentQuestCreateForm({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_ParentQuestCreateForm> createState() =>
      _ParentQuestCreateFormState();
}

class _ParentQuestCreateFormState extends ConsumerState<_ParentQuestCreateForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();
  String _type = 'one_time';
  final Set<String> _selectedChildren = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reward.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyChildLite>>(
      future: ref.read(questsRepositoryProvider).getFamilyChildren(widget.familyId),
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <FamilyChildLite>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Создать квест')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Название'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Введите название' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Описание'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        items: const [
                          DropdownMenuItem(value: 'one_time', child: Text('Разовый')),
                          DropdownMenuItem(value: 'point', child: Text('Точечный')),
                          DropdownMenuItem(value: 'routine', child: Text('Режимный')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'one_time'),
                        decoration: const InputDecoration(labelText: 'Тип'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reward,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Награда (монеты)'),
                        validator: (v) {
                          final value = int.tryParse((v ?? '').trim());
                          if (value == null || value < 0) return 'Укажите число >= 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Исполнители', style: Theme.of(context).textTheme.titleSmall),
                      ),
                      const SizedBox(height: 8),
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
                                  if (!(_formKey.currentState?.validate() ?? false)) return;
                                  if (_selectedChildren.isEmpty) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(content: Text('Выберите хотя бы одного ребёнка')),
                                    );
                                    return;
                                  }
                                  setState(() => _busy = true);
                                  try {
                                    await ref.read(questsRepositoryProvider).createQuest(
                                          title: _title.text,
                                          description: _description.text,
                                          rewardAmount: int.parse(_reward.text.trim()),
                                          questType: _type,
                                          dueAt: null,
                                          childIds: _selectedChildren.toList(),
                                        );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(content: Text('Квест создан')),
                                    );
                                    _title.clear();
                                    _description.clear();
                                    _reward.text = '10';
                                    setState(() => _selectedChildren.clear());
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(content: Text('Ошибка создания: $e')),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParentQuestReviewList extends ConsumerWidget {
  const _ParentQuestReviewList({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ParentReviewItem>>(
      future: ref.read(questsRepositoryProvider).getSubmittedForReview(familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentReviewItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('На проверке')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(),
                    if (list.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                      const Text('Нет заявок на проверку'),
                    ...list.map(
                      (item) => _ReviewCard(item: item),
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
        SnackBar(content: Text(approve ? 'Задание подтверждено' : 'Задание отклонено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка проверки: $e')),
      );
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
            Text(widget.item.title, style: Theme.of(context).textTheme.titleMedium),
            Text('Исполнитель: ${widget.item.childName}'),
            if (widget.item.submittedAt != null)
              Text('Отправлено: ${DateFormat('dd.MM HH:mm').format(widget.item.submittedAt!.toLocal())}'),
            if ((widget.item.evidencePath ?? '').isNotEmpty)
              Text('Фото: ${widget.item.evidencePath}'),
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

