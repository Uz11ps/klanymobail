import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../home/child_soft_ui.dart';
import '../../home/parent_shell_cache.dart';
import '../../../core/klany_bottom_sheet.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/klany_error_view.dart';
import '../../wallet/family_economy.dart';
import '../quests_repository.dart';
import 'exchange_quest_card.dart';
import 'task_exchange_figma_layout.dart';

class ParentTaskExchangeReviewList extends ConsumerWidget {
  const ParentTaskExchangeReviewList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellAsync = ref.watch(parentShellCacheProvider);
    if (shellAsync.isLoading && shellAsync.asData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shellAsync.hasError && shellAsync.asData == null) {
      return KlanyFriendlyErrorText(shellAsync.error);
    }
    final list = shellAsync.asData?.value.reviews ?? const <ParentReviewItem>[];
    if (list.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.2,
        child: const Center(
          child: Text(
            'Нет заявок на проверку',
            textAlign: TextAlign.center,
            style: TextStyle(color: kChildInkMuted),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final item in list)
          Padding(
            padding: EdgeInsets.only(
              bottom: context.klanySize(TaskExchangeFigmaLayout.cardListGap),
            ),
            child: _ExchangeReviewCard(
              item: item,
              background: TaskExchangeFigmaLayout.cardColorForKey(item.questId),
              onReviewCompleted: () =>
                  ref.read(parentShellCacheProvider.notifier).refresh(
                        force: true,
                      ),
            ),
          ),
      ],
    );
  }
}

class _ExchangeReviewCard extends ConsumerStatefulWidget {
  const _ExchangeReviewCard({
    required this.item,
    required this.background,
    this.onReviewCompleted,
  });

  final ParentReviewItem item;
  final Color background;
  final VoidCallback? onReviewCompleted;

  @override
  ConsumerState<_ExchangeReviewCard> createState() => _ExchangeReviewCardState();
}

class _ExchangeReviewCardState extends ConsumerState<_ExchangeReviewCard> {
  bool _busy = false;

  Future<void> _review(bool approve, {String comment = ''}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(questsRepositoryProvider).reviewSubmission(
            questId: widget.item.questId,
            childId: widget.item.childId,
            approve: approve,
            comment: comment,
          );
      if (!mounted) return;
      widget.onReviewCompleted?.call();
      context.showKlanySnackBar(
        SnackBar(
          content: Text(
            approve ? 'Задание подтверждено' : 'Задание отклонено',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showKlanyErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReviewSheet() async {
    final commentCtrl = TextEditingController();
    final result = await showKlanyModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kChildInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Исполнитель: ${widget.item.childName}',
              style: const TextStyle(fontSize: 13, color: kChildInkMuted),
            ),
            if (widget.item.submittedAt != null)
              Text(
                'Отправлено: ${DateFormat('dd.MM HH:mm').format(widget.item.submittedAt!.toLocal())}',
                style: const TextStyle(fontSize: 13, color: kChildInkMuted),
              ),
            if ((widget.item.evidenceUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    widget.item.evidenceUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(hintText: 'Комментарий'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Подтвердить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await _review(result, comment: commentCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxRate = ref.watch(familyGlobalTaxProvider);
    final gross = widget.item.rewardGross ?? widget.item.rewardAmount ?? 0;
    final hasPhoto = (widget.item.evidenceUrl ?? '').isNotEmpty;
    final cardRadius = context.klanySize(TaskExchangeFigmaLayout.cardRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: _busy ? null : _openReviewSheet,
        child: ExchangeQuestCard(
          background: widget.background,
          title: widget.item.title,
          coins: netQuestReward(gross, taxRate),
          assigneeChildId: widget.item.childId,
          assigneeName: widget.item.childName,
          trailing: ExchangeReviewPhotoBadge(photoCount: hasPhoto ? 1 : 0),
        ),
      ),
    );
  }
}
