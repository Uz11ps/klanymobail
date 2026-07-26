import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
import '../../home/parent_main_bottom_bar.dart';
import '../../home/parent_screen_header.dart';
import '../../../core/value_bump.dart';
import '../quests_repository.dart';
import 'parent_task_exchange_sections.dart';
import 'quest_create_figma_sheet.dart';
import 'exchange_quest_card.dart';
import 'task_exchange_figma_layout.dart';

/// Биржа задач — Figma 1:1431 / 1:1495 / 1:1569.
class ParentTaskExchangePage extends ConsumerStatefulWidget {
  const ParentTaskExchangePage({
    super.key,
    this.initialSegment = 0,
    this.onBack,
  });

  /// 0 свободные, 1 в работе, 2 проверка.
  final int initialSegment;
  final VoidCallback? onBack;

  @override
  ConsumerState<ParentTaskExchangePage> createState() =>
      _ParentTaskExchangePageState();
}

class _ParentTaskExchangePageState extends ConsumerState<ParentTaskExchangePage> {
  late int _segment;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment.clamp(0, 2);
    _poll = Timer.periodic(kParentLivePollInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ParentTaskExchangePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      _segment = widget.initialSegment.clamp(0, 2);
    }
  }

  Future<void> _createQuest() async {
    final family = ref.read(parentFamilyContextProvider).asData?.value;
    if (family == null) return;
    await showQuestCreateFigmaSheet(context, familyId: family.familyId);
    if (mounted) setState(() {});
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
            final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
            final navPillHeight =
                ParentMainBottomBarLayout.scaledPillHeight(context);
            final mainNavInset =
                widget.onBack != null ? navPillHeight + context.klanySize(16) : 0.0;
            final fabBottom = context.klanySize(24) + bottomInset + mainNavInset;
            final fabSize = context.klanySize(TaskExchangeFigmaLayout.fabHitSize);
            final tabGap = context.klanySize(TaskExchangeFigmaLayout.tabGap);
            final listHMargin = context.klanySize(TaskExchangeFigmaLayout.hMargin);
            return SafeArea(
              bottom: false,
              child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ParentScreenHeader(
                          title: 'Биржа',
                          onBack: widget.onBack,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            listHMargin,
                            context.klanySize(8),
                            listHMargin,
                            context.klanySize(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ExchangeTab(
                                  label: 'Свободные',
                                  selected: _segment == 0,
                                  onTap: () => setState(() => _segment = 0),
                                ),
                              ),
                              SizedBox(width: tabGap),
                              Expanded(
                                child: _ExchangeTab(
                                  label: 'В работе',
                                  selected: _segment == 1,
                                  onTap: () => setState(() => _segment = 1),
                                ),
                              ),
                              SizedBox(width: tabGap),
                              Expanded(
                                child: _ExchangeTab(
                                  label: 'Проверка',
                                  selected: _segment == 2,
                                  onTap: () => setState(() => _segment = 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                listHMargin,
                                0,
                                listHMargin,
                                fabBottom + fabSize + context.klanySize(16),
                              ),
                              children: [
                                if (_segment == 0)
                                  _ExchangeNewQuestList(familyId: family.familyId)
                                else if (_segment == 1)
                                  _ExchangeInWorkQuestList(familyId: family.familyId)
                                else
                                  ParentTaskExchangeReviewList(
                                    familyId: family.familyId,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: context.klanySize(11),
                      bottom: fabBottom,
                      child: Material(
                        color: TaskExchangeFigmaLayout.fabFill,
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _createQuest,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: fabSize,
                            height: fabSize,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/figma/exchange_fab_plus.svg',
                                width: context.klanySize(TaskExchangeFigmaLayout.fabPlusSize),
                                height: context.klanySize(TaskExchangeFigmaLayout.fabPlusSize),
                              ),
                            ),
                          ),
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

class _ExchangeTab extends StatelessWidget {
  const _ExchangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tabHeight = context.klanySize(TaskExchangeFigmaLayout.tabHeight);
    final tabRadius = context.klanySize(TaskExchangeFigmaLayout.tabRadius);
    final baseStyle = selected
        ? TaskExchangeFigmaLayout.tabActiveStyle
        : TaskExchangeFigmaLayout.tabIdleStyle;
    final textStyle = context.klanyTextStyle(baseStyle);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: tabHeight,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.klanySize(4)),
        decoration: BoxDecoration(
          color: selected
              ? TaskExchangeFigmaLayout.tabActiveFill
              : Colors.white,
          borderRadius: BorderRadius.circular(tabRadius),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ),
      ),
    );
  }
}

class _ExchangeNewQuestList extends ConsumerWidget {
  const _ExchangeNewQuestList({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ParentQuestItem>>(
      future: ref.read(questsRepositoryProvider).getParentQuests(familyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }
        final list = (snapshot.data ?? const <ParentQuestItem>[])
            .where(
              (q) =>
                  q.status == 'active' &&
                  q.distributionType == 'exchange' &&
                  q.childIds.isEmpty,
            )
            .toList();
        if (list.isEmpty) {
          return _ExchangeEmptyState(message: 'Нет свободных задач');
        }
        return Column(
          children: [
            for (final q in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExchangeQuestCard(
                  background: TaskExchangeFigmaLayout.cardColorForKey(q.id),
                  title: q.title,
                  coins: q.rewardAmount,
                  trailing: Text(
                    _formatCreated(q.createdAt),
                    style: context.klanyTextStyle(
                      TaskExchangeFigmaLayout.metaStyle,
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

class _ExchangeInWorkQuestList extends ConsumerWidget {
  const _ExchangeInWorkQuestList({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(questsRepositoryProvider);
    return FutureBuilder<(List<ParentQuestItem>, List<FamilyChildLite>)>(
      future: Future.wait([
        repo.getParentQuests(familyId),
        repo.getFamilyChildren(familyId),
      ]).then((r) => (r[0] as List<ParentQuestItem>, r[1] as List<FamilyChildLite>)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }
        final quests = snapshot.data?.$1 ?? const <ParentQuestItem>[];
        final children = snapshot.data?.$2 ?? const <FamilyChildLite>[];
        final namesById = {
          for (final c in children) c.id: c.displayName,
        };
        final list = quests
            .where(
              (q) =>
                  q.status == 'active' &&
                  (q.childIds.isNotEmpty || q.distributionType != 'exchange'),
            )
            .toList();
        if (list.isEmpty) {
          return const _ExchangeEmptyState(message: 'Нет задач в работе');
        }
        return Column(
          children: [
            for (final q in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExchangeQuestCard(
                  background: TaskExchangeFigmaLayout.cardColorForKey(q.id),
                  title: q.title,
                  coins: q.rewardAmount,
                  assigneeChildId:
                      q.childIds.isEmpty ? null : q.childIds.first,
                  assigneeName: q.childIds.isEmpty
                      ? null
                      : namesById[q.childIds.first],
                  trailing: _ExchangeDeadlineLabel(quest: q),
                  coinsStyle: TaskExchangeFigmaLayout.cardCoinsBoldStyle,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExchangeDeadlineLabel extends StatelessWidget {
  const _ExchangeDeadlineLabel({required this.quest});

  final ParentQuestItem quest;

  @override
  Widget build(BuildContext context) {
    final deadline = TaskExchangeFigmaLayout.resolveDeadline(
      dueAt: quest.dueAt,
      timeLimitMinutes: quest.timeLimitMinutes,
      assigneeSince: quest.assigneeSince,
      createdAt: quest.createdAt,
    );
    if (deadline == null) {
      return Text(
        'Без срока',
        style: context.klanyTextStyle(TaskExchangeFigmaLayout.metaStyle),
      );
    }
    final urgent = TaskExchangeFigmaLayout.isDeadlineUrgent(deadline);
    return Text(
      TaskExchangeFigmaLayout.remainingLabel(deadline),
      textAlign: TextAlign.right,
      style: context.klanyTextStyle(
        TaskExchangeFigmaLayout.deadlineStyle.copyWith(
          color: urgent ? TaskExchangeFigmaLayout.deadlineUrgent : Colors.black,
          fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _ExchangeEmptyState extends StatelessWidget {
  const _ExchangeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.32,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kChildInkMuted,
            fontSize: context.klanySize(16),
          ),
        ),
      ),
    );
  }
}

String _formatCreated(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year && local.month == now.month && local.day == now.day;
  final time = DateFormat('HH:mm').format(local);
  if (isToday) return 'Сегодня, $time';
  return DateFormat('d MMM, HH:mm', 'ru').format(local);
}
