import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import 'task_exchange_figma_layout.dart';

/// Аватар + имя исполнителя (Figma 1:1495 / 1:1569).
class ExchangeAssigneeColumn extends StatelessWidget {
  const ExchangeAssigneeColumn({
    super.key,
    required this.childId,
    required this.name,
  });

  final String childId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final avatarSize = context.klanySize(43);
    final label = name.trim().isEmpty ? '—' : name.trim();
    final initial = label == '—'
        ? '?'
        : String.fromCharCode(label.runes.first).toUpperCase();

    return SizedBox(
      width: avatarSize,
      child: Column(
        children: [
          UserAvatar(
            userKey: 'child:$childId',
            size: avatarSize,
            fallbackText: initial,
          ),
          SizedBox(height: context.klanySize(4)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.klanyTextStyle(
              const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
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
    this.coinsStyle = TaskExchangeFigmaLayout.cardCoinsStyle,
  });

  final Color background;
  final String title;
  final int coins;
  final Widget? trailing;
  final String? assigneeChildId;
  final String? assigneeName;
  final TextStyle coinsStyle;

  @override
  Widget build(BuildContext context) {
    final cardRadius = context.klanySize(TaskExchangeFigmaLayout.cardRadius);
    final padH = context.klanySize(16);
    final padTop = context.klanySize(16);
    final padBottom = context.klanySize(14);
    final scale = context.klanyScale;
    final showAssignee =
        assigneeChildId != null && assigneeChildId!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: TaskExchangeFigmaLayout.cardShadows(background, scale: scale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAssignee) ...[
            ExchangeAssigneeColumn(
              childId: assigneeChildId!,
              name: assigneeName ?? '',
            ),
            SizedBox(width: context.klanySize(12)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(width: context.klanySize(8)),
                      trailing!,
                    ],
                  ],
                ),
                SizedBox(height: context.klanySize(8)),
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

/// Блок «N фото ›» справа (Figma 1:1569).
class ExchangeReviewPhotoBadge extends StatelessWidget {
  const ExchangeReviewPhotoBadge({super.key, required this.photoCount});

  final int photoCount;

  @override
  Widget build(BuildContext context) {
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
          width: context.klanySize(16),
          height: context.klanySize(16),
          colorFilter: const ColorFilter.mode(
            TaskExchangeFigmaLayout.metaGray,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}
