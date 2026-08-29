import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
import '../../home/parent_main_bottom_bar.dart';
import '../../home/parent_shell_cache.dart';
import '../../home/parent_screen_header.dart';
import '../../../core/klany_error_view.dart';
import '../../../core/klany_live_poll.dart';
import '../../wallet/family_economy.dart';
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
    this.embeddedInHomeTab = false,
  });

  /// 0 свободные, 1 в работе, 2 проверка.
  final int initialSegment;
  final VoidCallback? onBack;

  /// Зарезервировать место под [ParentMainBottomBar] на главном экране.
  final bool embeddedInHomeTab;

  @override
  ConsumerState<ParentTaskExchangePage> createState() =>
      _ParentTaskExchangePageState();
}

class _ParentTaskExchangePageState extends ConsumerState<ParentTaskExchangePage>
    with KlanyLivePollConsumerMixin {
  late int _segment;

  @override
  void onKlanyLivePoll({bool silent = true}) {
    refreshParentShellCache(ref);
  }

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment.clamp(0, 2);
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
    if (mounted) {
      klanyLivePollBump(ref);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    final family = familyAsync.asData?.value;
    if (familyAsync.isLoading && family == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (familyAsync.hasError && family == null) {
      return KlanyErrorGoBack(
        error: familyAsync.error!,
        onBack: widget.onBack,
      );
    }
    if (family == null) {
      return const Center(child: Text('Семья не найдена'));
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final navPillHeight = ParentMainBottomBarLayout.scaledPillHeight(context);
    final mainNavInset = widget.embeddedInHomeTab
        ? navPillHeight + context.klanySize(16)
        : 0.0;
    final fabBottom = context.klanySize(24) + bottomInset + mainNavInset;
    final fabSize = context.klanySize(TaskExchangeFigmaLayout.fabHitSize);
    final listHMargin = context.klanySize(TaskExchangeFigmaLayout.hMargin);
    return SizedBox.expand(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParentScreenHeader(
                  title: 'Биржа',
                  onBack: widget.onBack,
                  padding: EdgeInsets.fromLTRB(
                    listHMargin,
                    context.klanySize(10),
                    listHMargin,
                    context.klanySize(4),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    listHMargin,
                    context.klanySize(4),
                    listHMargin,
                    context.klanySize(8),
                  ),
                  child: _ExchangeTabBar(
                    segment: _segment,
                    onSegmentSelected: (i) => setState(() => _segment = i),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(parentShellCacheProvider.notifier).refresh(
                              force: true,
                            ),
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
                          const _ExchangeNewQuestList()
                        else if (_segment == 1)
                          const _ExchangeInWorkQuestList()
                        else
                          const ParentTaskExchangeReviewList(),
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
                        width: context.klanySize(
                          TaskExchangeFigmaLayout.fabPlusSize,
                        ),
                        height: context.klanySize(
                          TaskExchangeFigmaLayout.fabPlusSize,
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
  }
}

class _ExchangeTabBar extends ConsumerWidget {
  const _ExchangeTabBar({
    required this.segment,
    required this.onSegmentSelected,
  });

  final int segment;
  final ValueChanged<int> onSegmentSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(parentShellCacheProvider).asData?.value;
    final quests = cache?.quests ?? const <ParentQuestItem>[];
    final reviews = cache?.reviews ?? const <ParentReviewItem>[];
    final counts = (
      free: quests.where(isParentQuestFreeOnExchange).length,
      inWork: quests.where(isParentQuestInWork).length,
      review: reviews.length,
    );
    final tabGap = context.klanySize(TaskExchangeFigmaLayout.tabGap);
    return Row(
      children: [
        Expanded(
          child: _ExchangeTab(
            label: 'Свободные',
            selected: segment == 0,
            badgeCount: counts.free,
            onTap: () => onSegmentSelected(0),
          ),
        ),
        SizedBox(width: tabGap),
        Expanded(
          child: _ExchangeTab(
            label: 'В работе',
            selected: segment == 1,
            badgeCount: counts.inWork,
            onTap: () => onSegmentSelected(1),
          ),
        ),
        SizedBox(width: tabGap),
        Expanded(
          child: _ExchangeTab(
            label: 'Проверка',
            selected: segment == 2,
            badgeCount: counts.review,
            onTap: () => onSegmentSelected(2),
          ),
        ),
      ],
    );
  }
}

class _ExchangeTab extends StatelessWidget {
  const _ExchangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
          if (badgeCount > 0)
            Positioned(
              top: -context.klanySize(4),
              right: -context.klanySize(2),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: context.klanySize(17),
                  minHeight: context.klanySize(17),
                ),
                padding: EdgeInsets.symmetric(horizontal: context.klanySize(4)),
                decoration: BoxDecoration(
                  color: const Color(0xFFD83A3A),
                  borderRadius: BorderRadius.circular(context.klanySize(10)),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.klanySize(9),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExchangeNewQuestList extends ConsumerWidget {
  const _ExchangeNewQuestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxRate = ref.watch(familyGlobalTaxProvider);
    final shellAsync = ref.watch(parentShellCacheProvider);
    if (shellAsync.isLoading && shellAsync.asData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shellAsync.hasError && shellAsync.asData == null) {
      return KlanyFriendlyErrorText(shellAsync.error);
    }
    final list = (shellAsync.asData?.value.quests ?? const <ParentQuestItem>[])
        .where(isParentQuestFreeOnExchange)
        .toList();
    if (list.isEmpty) {
      return _ExchangeEmptyState(message: 'Нет свободных задач');
    }
    return Column(
      children: [
        for (final q in list)
          Padding(
            padding: EdgeInsets.only(
              bottom: context.klanySize(TaskExchangeFigmaLayout.cardListGap),
            ),
            child: ExchangeQuestCard(
              background: TaskExchangeFigmaLayout.cardColorForKey(q.id),
              title: q.title,
              coins: netQuestReward(q.rewardAmount, taxRate),
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
  }
}

class _ExchangeInWorkQuestList extends ConsumerWidget {
  const _ExchangeInWorkQuestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxRate = ref.watch(familyGlobalTaxProvider);
    final shellAsync = ref.watch(parentShellCacheProvider);
    if (shellAsync.isLoading && shellAsync.asData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shellAsync.hasError && shellAsync.asData == null) {
      return KlanyFriendlyErrorText(shellAsync.error);
    }
    final cache = shellAsync.asData!.value;
    final quests = cache.quests;
    final children = cache.familyChildren;
    final walletsByChildId = {
      for (final w in cache.wallets) w.childId: w,
    };
    final namesById = {
      for (final c in children) c.id: c.displayName,
    };
    final list = quests.where(isParentQuestInWork).toList();
    if (list.isEmpty) {
      return const _ExchangeEmptyState(message: 'Нет задач в работе');
    }
    return Column(
      children: [
        for (final q in list)
          Padding(
            padding: EdgeInsets.only(
              bottom: context.klanySize(TaskExchangeFigmaLayout.cardListGap),
            ),
            child: ExchangeQuestCard(
              background: TaskExchangeFigmaLayout.cardColorForKey(q.id),
              title: q.title,
              coins: netQuestReward(q.rewardAmount, taxRate),
              assigneeChildId: q.childIds.isEmpty ? null : q.childIds.first,
              assigneeName:
                  q.childIds.isEmpty ? null : namesById[q.childIds.first],
              assigneeAvatarObjectKey: q.childIds.isEmpty
                  ? null
                  : walletsByChildId[q.childIds.first]?.avatarObjectKey,
              assigneeAvatarImageUrl: q.childIds.isEmpty
                  ? null
                  : walletsByChildId[q.childIds.first]?.avatarImageUrl,
              trailing: isParentQuestOnReview(q)
                  ? const ExchangeReviewStatusBadge()
                  : _ExchangeDeadlineLabel(quest: q),
              coinsStyle: TaskExchangeFigmaLayout.cardCoinsBoldStyle,
            ),
          ),
      ],
    );
  }
}

class _ExchangeDeadlineLabel extends StatelessWidget {
  const _ExchangeDeadlineLabel({required this.quest});

  final ParentQuestItem quest;

  @override
  Widget build(BuildContext context) {
    if (isParentQuestOnReview(quest)) {
      return const ExchangeReviewStatusBadge();
    }
    final deadline = TaskExchangeFigmaLayout.resolveDeadline(
      dueAt: quest.dueAt,
      timeLimitMinutes: quest.timeLimitMinutes,
      assigneeSince: quest.assigneeSince,
      createdAt: quest.createdAt,
    );
    if (deadline == null) {
      return Text(
        'Без срока',
        textAlign: TextAlign.right,
        style: context.klanyTextStyle(TaskExchangeFigmaLayout.metaStyle),
      );
    }
    return ExchangeDeadlineColumn(deadline: deadline);
  }
}

class _ExchangeEmptyState extends StatelessWidget {
  const _ExchangeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.2,
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
