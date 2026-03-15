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
        if (family == null)
          return const Center(child: Text('Семья не найдена'));

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
              NavigationDestination(
                icon: Icon(Icons.add_task),
                label: 'Создать',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check),
                label: 'Проверка',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParentQuestsList extends ConsumerStatefulWidget {
  const _ParentQuestsList({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_ParentQuestsList> createState() => _ParentQuestsListState();
}

class _ParentQuestsListState extends ConsumerState<_ParentQuestsList> {
  Future<List<ParentQuestItem>>? _future;

  void _reload() {
    setState(() {
      _future = ref
          .read(questsRepositoryProvider)
          .getParentQuests(widget.familyId);
    });
  }

  Future<void> _editQuest(ParentQuestItem q) async {
    final repo = ref.read(questsRepositoryProvider);
    final children = await repo.getFamilyChildren(widget.familyId);
    if (!mounted) return;

    final titleCtl = TextEditingController(text: q.title);
    final descriptionCtl = TextEditingController(text: q.description);
    final rewardCtl = TextEditingController(text: q.rewardAmount.toString());
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
    var distributionType = q.distributionType == 'exchange'
        ? 'exchange'
        : 'assigned';
    var autoApprove = q.autoApprove;
    var hasTimeLimit = q.timeLimitMinutes != null;
    var scheduleType =
        q.scheduleType == 'daily' ||
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
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                            decoration: const InputDecoration(
                              labelText: 'Часы',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: minutesCtl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Минуты',
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (type == 'recurring') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: scheduleType == 'none'
                          ? 'daily'
                          : scheduleType,
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
                        children:
                            [
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Награда должна быть >= 0')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Квест обновлён')));
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel(String v) {
      switch (v) {
        case 'recurring':
          return 'Повторяющаяся';
        case 'unique':
          return 'Уникальная';
        default:
          return 'Разовая';
      }
    }

    return FutureBuilder<List<ParentQuestItem>>(
      future:
          _future ??
          ref.read(questsRepositoryProvider).getParentQuests(widget.familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentQuestItem>[];
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Квесты'),
              actions: [
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
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
                    if (!snapshot.hasData &&
                        snapshot.connectionState != ConnectionState.waiting)
                      const Text('Нет данных'),
                    ...list.map(
                      (q) => Card(
                        child: ListTile(
                          title: Text(q.title),
                          subtitle: Text(
                            '${typeLabel(q.questType)} • ${q.distributionType == 'exchange' ? 'Биржа' : 'Адресно'} • ${q.autoApprove ? 'Автоапрув' : 'Ручной апрув'}\n'
                            'Статус: ${q.status} • ${q.rewardAmount} монет • ${DateFormat('dd.MM HH:mm').format(q.createdAt.toLocal())}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editQuest(q);
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Удалить квест'),
                                    content: const Text(
                                      'Удалить квест полностью?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Отмена'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
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
                                    const SnackBar(
                                      content: Text('Квест удалён'),
                                    ),
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

class _ParentQuestCreateFormState
    extends ConsumerState<_ParentQuestCreateForm> {
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
  final Set<String> _scheduleDays = <String>{};
  final Set<String> _selectedChildren = <String>{};
  bool _busy = false;

  static const Map<String, List<String>> _presets = <String, List<String>>{
    'recurring': <String>[
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
    'one_time': <String>[
      'Сходить в магазин',
      'Помыть посуду',
      'Почистить обувь',
      'Провести влажную уборку',
      'Пропылесосить',
      'Приготовить еду',
    ],
    'unique': <String>[
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

  List<String> get _presetItems => <String>[
    'custom',
    ...(_presets[_type] ?? const <String>[]),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyChildLite>>(
      future: ref
          .read(questsRepositoryProvider)
          .getFamilyChildren(widget.familyId),
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
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: CircularProgressIndicator(),
                        ),
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Ошибка загрузки детей: ${snapshot.error}',
                          ),
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
                          _scheduleType = _type == 'recurring'
                              ? 'daily'
                              : 'none';
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
                        subtitle: const Text(
                          'Снимите, если нужна полностью своя задача',
                        ),
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
                                    title == 'custom'
                                        ? 'Свободная задача'
                                        : title,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _preset = v ?? 'custom';
                              if (_preset != 'custom') _title.text = _preset;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Выбор задачи',
                            prefixIcon: Icon(Icons.playlist_add_check),
                          ),
                        ),
                      if (!_usePreset || _preset == 'custom')
                        TextFormField(
                          controller: _title,
                          enabled: true,
                          decoration: const InputDecoration(
                            labelText: 'Название',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Введите название'
                              : null,
                        ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Распределение',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _autoApprove,
                        onChanged: (v) => setState(() => _autoApprove = v),
                        title: const Text('Автоподтверждение'),
                        subtitle: const Text(
                          'Награда зачисляется сразу после выполнения',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _hasTimeLimit,
                        onChanged: (v) =>
                            setState(() => _hasTimeLimit = v == true),
                        title: const Text('Лимит времени'),
                        subtitle: const Text(
                          'Таймер запускается при появлении/взятии задачи',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_hasTimeLimit)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _hours,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Часы',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _minutes,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Минуты',
                                ),
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
                          decoration: const InputDecoration(
                            labelText: 'График повторения',
                          ),
                        ),
                        if (_scheduleType == 'custom_days') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children:
                                [
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
                        decoration: const InputDecoration(
                          labelText: 'Награда (монеты)',
                        ),
                        validator: (v) {
                          final value = int.tryParse((v ?? '').trim());
                          if (value == null || value < 0)
                            return 'Укажите число >= 0';
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
                          subtitle: Text(
                            'Любой ребенок сможет взять ее в работу',
                          ),
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
                                  if (!(_formKey.currentState?.validate() ??
                                      false))
                                    return;
                                  if (_distributionType == 'assigned' &&
                                      _selectedChildren.isEmpty) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Выберите хотя бы одного ребёнка',
                                        ),
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
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
                                          rewardAmount: int.parse(
                                            _reward.text.trim(),
                                          ),
                                          questType: _type,
                                          dueAt: null,
                                          childIds:
                                              _distributionType == 'assigned'
                                              ? _selectedChildren.toList()
                                              : const <String>[],
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
                                              : const <String>[],
                                        );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text('Квест создан'),
                                      ),
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
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
      future: ref
          .read(questsRepositoryProvider)
          .getSubmittedForReview(familyId),
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
                    if (snapshot.hasError)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Ошибка: ${snapshot.error}'),
                        ),
                      ),
                    if (list.isEmpty &&
                        snapshot.connectionState != ConnectionState.waiting)
                      const Text('Нет заявок на проверку'),
                    ...list.map((item) => _ReviewCard(item: item)),
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
      await ref
          .read(questsRepositoryProvider)
          .reviewSubmission(
            questId: widget.item.questId,
            childId: widget.item.childId,
            approve: approve,
            comment: _comment.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Задание подтверждено' : 'Задание отклонено'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка проверки: $e')));
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
                            errorBuilder: (_, __, ___) => Center(
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
