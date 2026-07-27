import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/app_snackbar.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../quests_repository.dart';

/// Figma [node 256:447](https://www.figma.com/design/kwVuEbSWPdrTEFsrIvZVB3/Untitled?node-id=256-447).
const Color _kCreateSheetBlue = Color(0xFFBFDBFF);
const Color _kCreateHandle = Color(0xFFB5B5B5);
const double _kCreateSheetTopRadius = 36;
const double _kCreateFieldRadius = 26;
const double _kCreateFieldHeight = 60;
const double _kCreateCommentHeight = 112;
const double _kCreateSectionGap = 24;
const double _kCreateButtonHeight = 75;
const double _kCreateButtonRadius = 14;
const double _kCreateVerifyPillHeight = 64;
const double _kCreateVerifyPillRadius = 40;

const TextStyle _kCreateTitleStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 32,
  fontWeight: FontWeight.w800,
  color: Colors.black,
  height: 1.02,
);

const TextStyle _kCreateLabelStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: Colors.black,
  height: 1.2,
);

const TextStyle _kCreateFieldTextStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 20,
  fontWeight: FontWeight.w500,
  color: Colors.black,
  height: 1.36,
);

const TextStyle _kCreateFieldBoldStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: Colors.black,
  height: 1.36,
);

const TextStyle _kCreateButtonLabelStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: Colors.black,
  height: 1.0,
);

const TextStyle _kCreateVerifyTitleStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: Colors.black,
  height: 1.36,
);

const TextStyle _kCreateVerifySubtitleStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: Colors.black,
  height: 1.35,
);

Future<void> showQuestCreateFigmaSheet(
  BuildContext context, {
  required String familyId,
  VoidCallback? onCreated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(_kCreateSheetTopRadius),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.92;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _QuestCreateFigmaForm(
            familyId: familyId,
            onCreated: onCreated,
          ),
        ),
      );
    },
  );
}

class _QuestCreateFigmaForm extends ConsumerStatefulWidget {
  const _QuestCreateFigmaForm({
    required this.familyId,
    this.onCreated,
  });

  final String familyId;
  final VoidCallback? onCreated;

  @override
  ConsumerState<_QuestCreateFigmaForm> createState() =>
      _QuestCreateFigmaFormState();
}

class _QuestCreateFigmaFormState extends ConsumerState<_QuestCreateFigmaForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController(text: '100');
  final _formKey = GlobalKey<FormState>();

  String _type = 'one_time';
  String _distributionType = 'exchange';
  bool _autoApprove = false;
  String _scheduleType = 'none';
  String _preset = 'custom';
  final Set<String> _scheduleDays = {};
  final Set<String> _selectedChildren = {};
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = const TimeOfDay(hour: 13, minute: 30);
  bool _busy = false;
  Future<List<FamilyChildLite>>? _childrenFuture;

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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _childrenFuture ??= ref
        .read(questsRepositoryProvider)
        .getFamilyChildren(widget.familyId);
  }

  List<String> get _presetItems => ['custom', ...(_presets[_type] ?? [])];

  String _typeLabel(String value) => switch (value) {
        'recurring' => 'Повторяющаяся',
        'one_time' => 'Разовая',
        'unique' => 'Уникальная',
        _ => value,
      };

  String _dueDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Сегодня';
    if (target == today.add(const Duration(days: 1))) return 'Завтра';
    return DateFormat('d MMM', 'ru').format(date);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  DateTime? _buildDueAt() {
    return DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
  }

  Future<void> _submit(List<FamilyChildLite> children) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_distributionType == 'assigned' && _selectedChildren.isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного ребёнка')),
      );
      return;
    }
    if (_type == 'recurring' &&
        _scheduleType == 'custom_days' &&
        _scheduleDays.isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день повторения')),
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
            dueAt: _buildDueAt(),
            childIds: _distributionType == 'assigned'
                ? _selectedChildren.toList()
                : const [],
            distributionType: _distributionType,
            autoApprove: _autoApprove,
            timeLimitMinutes: null,
            scheduleType: _type == 'recurring' ? _scheduleType : 'none',
            scheduleDays:
                _type == 'recurring' ? _scheduleDays.toList() : const [],
          );
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Квест создан')),
      );
      widget.onCreated?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка создания: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyChildLite>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <FamilyChildLite>[];
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(19, 12, 19, 28),
            children: [
              Center(
                child: Container(
                  width: 68,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _kCreateHandle.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Создать задачу', style: _kCreateTitleStyle),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: kChildBrandBlue),
                  ),
                ),
              _CreateLabel('Тип задачи'),
              _CreateDropdownField<String>(
                value: _type,
                labelStyle: _kCreateFieldBoldStyle,
                items: const ['recurring', 'one_time', 'unique'],
                itemLabel: _typeLabel,
                onChanged: (v) => setState(() {
                  _type = v ?? 'one_time';
                  _preset = 'custom';
                  _title.clear();
                  _scheduleType = _type == 'recurring' ? 'daily' : 'none';
                  _scheduleDays.clear();
                }),
              ),
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Шаблоны'),
              _CreateDropdownField<String>(
                value: _preset,
                displayText:
                    _preset == 'custom' ? 'Выберите шаблон' : _preset,
                items: _presetItems,
                itemLabel: (v) => v == 'custom' ? 'Свободная задача' : v,
                onChanged: (v) => setState(() {
                  _preset = v ?? 'custom';
                  if (_preset != 'custom') _title.text = _preset;
                }),
              ),
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Название задачи'),
              _CreateTextField(
                controller: _title,
                hint: 'Введите название задачи',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Комментарий (необязательно)'),
              _CreateTextField(
                controller: _description,
                hint: 'Добавьте комментарий',
                minLines: 3,
                maxLines: 5,
                height: _kCreateCommentHeight,
              ),
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Исполнитель'),
              _CreateRadioRow(
                label: 'Отправить на Биржу',
                selected: _distributionType == 'exchange',
                onTap: () => setState(() => _distributionType = 'exchange'),
              ),
              const SizedBox(height: 10),
              _CreateRadioRow(
                label: 'Выбрать ребенка',
                selected: _distributionType == 'assigned',
                onTap: () => setState(() => _distributionType = 'assigned'),
              ),
              if (_distributionType == 'assigned') ...[
                const SizedBox(height: 10),
                if (children.isEmpty)
                  const Text(
                    'Нет детей в семье',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      color: kChildInkMuted,
                    ),
                  )
                else
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CreateChildRadioRow(
                        childId: child.id,
                        label: child.displayName,
                        selected: _selectedChildren.contains(child.id),
                        onTap: () => setState(() {
                          if (_selectedChildren.contains(child.id)) {
                            _selectedChildren.remove(child.id);
                          } else {
                            _selectedChildren.add(child.id);
                          }
                        }),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Стоимость'),
              _CreateTextField(
                controller: _reward,
                hint: '100',
                keyboardType: TextInputType.number,
                prefix: Image.asset(
                  'assets/figma/quest_create_coin.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
                validator: (v) {
                  final value = int.tryParse((v ?? '').trim());
                  if (value == null || value < 0) {
                    return 'Укажите число >= 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Выполнить до'),
              Row(
                children: [
                  Expanded(
                    child: _CreateActionField(
                      iconAsset: 'assets/figma/quest_create_calendar.svg',
                      label: _dueDateLabel(_dueDate),
                      onTap: _pickDueDate,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _CreateActionField(
                      iconAsset: 'assets/figma/quest_create_alarm.svg',
                      label: _formatTime(_dueTime),
                      onTap: _pickDueTime,
                    ),
                  ),
                ],
              ),
              if (_type == 'recurring') ...[
                const SizedBox(height: _kCreateSectionGap),
                _CreateLabel('График повторения'),
                _CreateDropdownField<String>(
                  value: _scheduleType,
                  items: const ['daily', 'weekly', 'custom_days'],
                  itemLabel: (v) => switch (v) {
                    'daily' => 'Ежедневно',
                    'weekly' => 'Еженедельно',
                    'custom_days' => 'По выбранным дням',
                    _ => v,
                  },
                  onChanged: (v) =>
                      setState(() => _scheduleType = v ?? 'daily'),
                ),
                if (_scheduleType == 'custom_days') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                            label: Text(
                              d.$2,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            selected: _scheduleDays.contains(d.$1),
                            selectedColor: kBrandMint,
                            checkmarkColor: kChildInk,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
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
              const SizedBox(height: _kCreateSectionGap),
              _CreateLabel('Проверка выполнения'),
              _CreateVerifyPill(
                title: 'Требуется проверка',
                subtitle: 'Вы проверите и подтвердите',
                selected: !_autoApprove,
                onTap: () => setState(() => _autoApprove = false),
              ),
              const SizedBox(height: 10),
              _CreateVerifyPill(
                title: 'Автопруф',
                subtitle: 'Ребенок сам подтвердит',
                selected: _autoApprove,
                onTap: () => setState(() => _autoApprove = true),
              ),
              const SizedBox(height: _kCreateSectionGap),
              if (_busy)
                const SizedBox(
                  height: _kCreateButtonHeight,
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1F4F1B),
                      ),
                    ),
                  ),
                )
              else
                FigmaGradientButton(
                  label: 'Создать задачу',
                  gradient: FigmaGradientButton.mintGradientVertical,
                  height: _kCreateButtonHeight,
                  cornerRadius: _kCreateButtonRadius,
                  labelStyle: _kCreateButtonLabelStyle,
                  boxShadow: kFigmaLandingCtaBoxShadows,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  onTap: () => _submit(children),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _CreateLabel extends StatelessWidget {
  const _CreateLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: _kCreateLabelStyle),
      ),
    );
  }
}

class _CreateFieldShell extends StatelessWidget {
  const _CreateFieldShell({
    required this.child,
    this.height = _kCreateFieldHeight,
    this.onTap,
  });

  final Widget child;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCreateFieldRadius),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCreateFieldRadius),
        child: box,
      ),
    );
  }
}

class _CreateDropdownField<T> extends StatelessWidget {
  const _CreateDropdownField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.displayText,
    this.labelStyle = _kCreateFieldTextStyle,
  });

  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final String? displayText;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final shown = displayText ?? itemLabel(value);
    return _CreateFieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          style: labelStyle,
          icon: SvgPicture.asset(
            'assets/figma/quest_create_chevron.svg',
            width: 16,
            height: 16,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), style: labelStyle),
                ),
              )
              .toList(),
          onChanged: onChanged,
          selectedItemBuilder: (context) => List.generate(
            items.length,
            (_) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                shown,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTextField extends StatelessWidget {
  const _CreateTextField({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.prefix,
    this.minLines = 1,
    this.maxLines = 1,
    this.height = _kCreateFieldHeight,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final int minLines;
  final int maxLines;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => validator?.call(controller.text),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CreateFieldShell(
              height: height,
              child: Row(
                children: [
                  if (prefix != null) ...[
                    prefix!,
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      minLines: minLines,
                      maxLines: maxLines,
                      style: _kCreateFieldTextStyle,
                      onChanged: field.didChange,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: _kCreateFieldTextStyle.copyWith(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (field.hasError && field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade700,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CreateActionField extends StatelessWidget {
  const _CreateActionField({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CreateFieldShell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(iconAsset, width: 24, height: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: _kCreateFieldBoldStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SvgPicture.asset(
            'assets/figma/quest_create_chevron.svg',
            width: 16,
            height: 16,
          ),
        ],
      ),
    );
  }
}

class _CreateChildRadioRow extends StatelessWidget {
  const _CreateChildRadioRow({
    required this.childId,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String childId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();

    return _CreateFieldShell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(
            selected
                ? 'assets/figma/quest_create_radio_on.svg'
                : 'assets/figma/quest_create_radio_off.svg',
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 11),
          UserAvatar(
            userKey: 'child:$childId',
            size: _avatarSize,
            fallbackText: initial,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: _kCreateFieldTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateRadioRow extends StatelessWidget {
  const _CreateRadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CreateFieldShell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(
            selected
                ? 'assets/figma/quest_create_radio_on.svg'
                : 'assets/figma/quest_create_radio_off.svg',
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: _kCreateFieldTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateVerifyPill extends StatelessWidget {
  const _CreateVerifyPill({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kCreateSheetBlue : Colors.white,
      borderRadius: BorderRadius.circular(_kCreateVerifyPillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCreateVerifyPillRadius),
        child: Container(
          height: _kCreateVerifyPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCreateVerifyPillRadius),
            border: selected
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _kCreateVerifyTitleStyle),
              Text(subtitle, style: _kCreateVerifySubtitleStyle),
            ],
          ),
        ),
      ),
    );
  }
}
