import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../../core/storage_presign.dart';
import 'task_exchange_figma_layout.dart';

/// Аватар + имя исполнителя (Figma 1:1495 / 1:1569).
class ExchangeAssigneeColumn extends StatelessWidget {
  const ExchangeAssigneeColumn({
    super.key,
    required this.childId,
    required this.name,
    this.avatarObjectKey,
    this.avatarImageUrl,
  });

  final String childId;
  final String name;
  final String? avatarObjectKey;
  final String? avatarImageUrl;

  @override
  Widget build(BuildContext context) {
    final avatarSize =
        context.klanySize(TaskExchangeFigmaLayout.assigneeAvatarSize);
    final label = name.trim().isEmpty ? '—' : name.trim();
    final initial = label == '—'
        ? '?'
        : String.fromCharCode(label.runes.first).toUpperCase();
    final imageKey = (avatarObjectKey ?? '').trim();

    return SizedBox(
      width: avatarSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UserAvatar(
            userKey: 'child:$childId',
            size: avatarSize,
            fallbackText: initial,
            remoteImageUrl: avatarImageUrl,
            remoteDiskCacheKey: imageKey.isEmpty
                ? null
                : storageObjectDiskCacheKey('member-avatars', imageKey),
          ),
          SizedBox(height: context.klanySize(2)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.klanyTextStyle(
              const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка задачи на бирже (Figma 1:1431 / 1:1495).
class ExchangeQuestCard extends StatelessWidget {
  const ExchangeQuestCard({
    super.key,
    required this.background,
    required this.title,
    required this.coins,
    this.trailing,
    this.assigneeChildId,
    this.assigneeName,
    this.assigneeAvatarObjectKey,
    this.assigneeAvatarImageUrl,
    this.coinsStyle = TaskExchangeFigmaLayout.cardCoinsStyle,
  });

  final Color background;
  final String title;
  final int coins;
  final Widget? trailing;
  final String? assigneeChildId;
  final String? assigneeName;
  final String? assigneeAvatarObjectKey;
  final String? assigneeAvatarImageUrl;
  final TextStyle coinsStyle;

  @override
  Widget build(BuildContext context) {
    final cardRadius = context.klanySize(TaskExchangeFigmaLayout.cardRadius);
    final padH = context.klanySize(TaskExchangeFigmaLayout.cardPadH);
    final padV = context.klanySize(TaskExchangeFigmaLayout.cardPadV);
    final scale = context.klanyScale;
    final showAssignee =
        assigneeChildId != null && assigneeChildId!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow:
            TaskExchangeFigmaLayout.cardShadows(background, scale: scale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showAssignee) ...[
            ExchangeAssigneeColumn(
              childId: assigneeChildId!,
              name: assigneeName ?? '',
              avatarObjectKey: assigneeAvatarObjectKey,
              avatarImageUrl: assigneeAvatarImageUrl,
            ),
            SizedBox(width: context.klanySize(8)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.klanyTextStyle(
                          TaskExchangeFigmaLayout.cardTitleStyle,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      SizedBox(width: context.klanySize(4)),
                      trailing!,
                    ],
                  ],
                ),
                SizedBox(height: context.klanySize(3)),
                Text(
                  '$coins монет',
                  style: context.klanyTextStyle(coinsStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Две строки: «Осталось» и `HH:MM:SS` (Figma 1:1495).
class ExchangeDeadlineColumn extends StatelessWidget {
  const ExchangeDeadlineColumn({
    super.key,
    required this.deadline,
    this.now,
  });

  final DateTime deadline;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final parts = TaskExchangeFigmaLayout.remainingParts(deadline, now);
    final urgent = TaskExchangeFigmaLayout.isDeadlineUrgent(deadline, now);
    final urgentColor = TaskExchangeFigmaLayout.deadlineUrgent;

    if (parts.$2.isEmpty) {
      return Text(
        parts.$1,
        textAlign: TextAlign.right,
        style: context.klanyTextStyle(
          TaskExchangeFigmaLayout.deadlineHeadStyle.copyWith(
            color: urgent ? urgentColor : TaskExchangeFigmaLayout.metaGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts.$1,
          textAlign: TextAlign.right,
          style: context.klanyTextStyle(TaskExchangeFigmaLayout.deadlineHeadStyle),
        ),
        Text(
          parts.$2,
          textAlign: TextAlign.right,
          style: context.klanyTextStyle(
            TaskExchangeFigmaLayout.deadlineTimeStyle.copyWith(
              color: urgent ? urgentColor : Colors.black,
              fontWeight: urgent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Статус «На проверке» вместо таймера.
class ExchangeReviewStatusBadge extends StatelessWidget {
  const ExchangeReviewStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'На',
          textAlign: TextAlign.right,
          style: context.klanyTextStyle(TaskExchangeFigmaLayout.deadlineHeadStyle),
        ),
        Text(
          'проверке',
          textAlign: TextAlign.right,
          style: context.klanyTextStyle(
            TaskExchangeFigmaLayout.deadlineTimeStyle.copyWith(
              color: TaskExchangeFigmaLayout.deadlineUrgent,
            ),
          ),
        ),
      ],
    );
  }
}

/// Блок «N фото ›» справа (Figma 1:1569).
class ExchangeReviewPhotoBadge extends StatelessWidget {
  const ExchangeReviewPhotoBadge({super.key, required this.photoCount});

  final int photoCount;

  @override
  Widget build(BuildContext context) {
    if (photoCount <= 0) return const SizedBox.shrink();
    final label = photoCount == 1 ? '1 фото' : '$photoCount фото';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.klanyTextStyle(TaskExchangeFigmaLayout.metaStyle),
        ),
        SvgPicture.asset(
          'assets/figma/exchange_chevron_right.svg',
          width: context.klanySize(14),
          height: context.klanySize(14),
          colorFilter: const ColorFilter.mode(
            TaskExchangeFigmaLayout.metaGray,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}
