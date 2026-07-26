import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
import '../../../core/value_bump.dart';
import '../quests_repository.dart';
import 'parent_task_exchange_sections.dart';
import 'quest_create_figma_sheet.dart';
import 'task_exchange_figma_layout.dart';

/// Биржа задач — Figma 1:1431 / 1:1495 / 1:1569.
class ParentTaskExchangePage extends ConsumerStatefulWidget {
  const ParentTaskExchangePage({
    super.key,
    this.initialSegment = 0,
    this.showBackButton = false,
  });

  /// 0 новые, 1 в работе, 2 проверка.
  final int initialSegment;
  final bool showBackButton;

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
            return CloudBackground(
              opacity: 0.04,
              backgroundColor: const Color(0xFFFDFEFE),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: TaskExchangeFigmaLayout.headerPad,
                          child: Row(
                            children: [
                              if (widget.showBackButton) ...[
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.maybePop(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: SvgPicture.asset(
                                        'assets/figma/exchange_back_arrow.svg',
                                        width: 24,
                                        height: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              const Text('Биржа', style: TaskExchangeFigmaLayout.titleStyle),
                            ],
                          ),
                        ),
                        Padding(
                          padding: TaskExchangeFigmaLayout.tabsPad,
                          child: Row(
                            children: [
                              Expanded(
                                child: _ExchangeTab(
                                  label: 'Новые',
                                  selected: _segment == 0,
                                  onTap: () => setState(() => _segment = 0),
                                ),
                              ),
                              const SizedBox(width: TaskExchangeFigmaLayout.tabGap),
                              Expanded(
                                child: _ExchangeTab(
                                  label: 'В работе',
                                  selected: _segment == 1,
                                  onTap: () => setState(() => _segment = 1),
                                ),
                              ),
                              const SizedBox(width: TaskExchangeFigmaLayout.tabGap),
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
                              padding: TaskExchangeFigmaLayout.listPad,
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
                      right: 19,
                      bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                        child: InkWell(
                          onTap: _createQuest,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: TaskExchangeFigmaLayout.fabSize,
                            height: TaskExchangeFigmaLayout.fabSize,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/figma/exchange_fab_plus.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  kChildInk,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: TaskExchangeFigmaLayout.tabHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TaskExchangeFigmaLayout.tabActiveFill
              : Colors.white,
          borderRadius:
              BorderRadius.circular(TaskExchangeFigmaLayout.tabRadius),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: selected
              ? TaskExchangeFigmaLayout.tabActiveStyle
              : TaskExchangeFigmaLayout.tabIdleStyle,
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Нет новых задач', style: TextStyle(color: kChildInkMuted)),
            ),
          );
        }
        return Column(
          children: [
            for (final q in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExchangeQuestCard(
                  title: q.title,
                  coins: q.rewardAmount,
                  trailing: Text(
                    _formatCreated(q.createdAt),
                    style: TaskExchangeFigmaLayout.metaStyle,
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
                  (q.childIds.isNotEmpty || q.distributionType != 'exchange'),
            )
            .toList();
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Нет задач в работе', style: TextStyle(color: kChildInkMuted)),
            ),
          );
        }
        return Column(
          children: [
            for (final q in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExchangeQuestCard(
                  title: q.title,
                  coins: q.rewardAmount,
                  showAssignee: true,
                  assigneeLabel: q.childIds.isEmpty ? 'Биржа' : 'Исполнитель',
                  trailing: Text(
                    _formatDeadline(q.timeLimitMinutes),
                    style: TaskExchangeFigmaLayout.deadlineStyle,
                  ),
                  coinsStyle: TaskExchangeFigmaLayout.cardCoinsBoldStyle,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExchangeQuestCard extends StatelessWidget {
  const _ExchangeQuestCard({
    required this.title,
    required this.coins,
    this.trailing,
    this.showAssignee = false,
    this.assigneeLabel = '',
    this.coinsStyle = TaskExchangeFigmaLayout.cardCoinsStyle,
  });

  final String title;
  final int coins;
  final Widget? trailing;
  final bool showAssignee;
  final String assigneeLabel;
  final TextStyle coinsStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TaskExchangeFigmaLayout.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAssignee) ...[
            Column(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assigneeLabel,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TaskExchangeFigmaLayout.cardTitleStyle),
                const SizedBox(height: 8),
                Text('$coins монет', style: coinsStyle),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
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

String _formatDeadline(int? minutes) {
  if (minutes == null || minutes <= 0) return 'Без срока';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return 'Осталось ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
}
