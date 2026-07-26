import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../home/child_soft_ui.dart';
import '../../../core/app_snackbar.dart';
import '../quests_repository.dart';
import 'task_exchange_figma_layout.dart';

class ParentTaskExchangeReviewList extends ConsumerStatefulWidget {
  const ParentTaskExchangeReviewList({super.key, required this.familyId});
  final String familyId;

  @override
  ConsumerState<ParentTaskExchangeReviewList> createState() =>
      _ParentTaskExchangeReviewListState();
}

class _ParentTaskExchangeReviewListState
    extends ConsumerState<ParentTaskExchangeReviewList> {
  Future<List<ParentReviewItem>>? _future;

  void _reload() {
    setState(() {
      _future = ref
          .read(questsRepositoryProvider)
          .getSubmittedForReview(widget.familyId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ref
        .read(questsRepositoryProvider)
        .getSubmittedForReview(widget.familyId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ParentReviewItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }
        final list = snapshot.data ?? const <ParentReviewItem>[];
        if (list.isEmpty) {
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.32,
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
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExchangeReviewCard(
                  item: item,
                  onReviewCompleted: _reload,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExchangeReviewCard extends ConsumerStatefulWidget {
  const _ExchangeReviewCard({
    required this.item,
    this.onReviewCompleted,
  });

  final ParentReviewItem item;
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
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReviewSheet() async {
    final commentCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
    final hasPhoto = (widget.item.evidenceUrl ?? '').isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TaskExchangeFigmaLayout.cardRadius),
        onTap: _busy ? null : _openReviewSheet,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(TaskExchangeFigmaLayout.cardRadius),
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
              Column(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.item.childName.isNotEmpty
                            ? widget.item.childName.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.childName,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: TaskExchangeFigmaLayout.cardTitleStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.item.rewardAmount ?? 0} монет',
                      style: TaskExchangeFigmaLayout.cardCoinsStyle,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasPhoto ? '1 фо' : '0 фо',
                        style: TaskExchangeFigmaLayout.metaStyle,
                      ),
                      SvgPicture.asset(
                        'assets/figma/exchange_chevron_right.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          TaskExchangeFigmaLayout.metaGray,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
