import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/parent_access_repository.dart';
import '../auth/child_session.dart';
import '../notifications/notifications_repository.dart';
import '../quests/quests_repository.dart';
import '../wallet/wallet_repository.dart';

/// Данные главного экрана родителя — один prefetch до показа shell.
class ParentShellData {
  const ParentShellData({
    required this.family,
    required this.wallets,
    required this.reviews,
    required this.quests,
    required this.notifications,
  });

  final ParentFamilyContext? family;
  final List<ParentChildWalletItem> wallets;
  final List<ParentReviewItem> reviews;
  final List<ParentQuestItem> quests;
  final List<InAppNotificationItem> notifications;
}

final parentShellDataProvider = FutureProvider<ParentShellData>((ref) async {
  final family = await ref.watch(parentFamilyContextProvider.future);
  if (family == null) {
    return const ParentShellData(
      family: null,
      wallets: <ParentChildWalletItem>[],
      reviews: <ParentReviewItem>[],
      quests: <ParentQuestItem>[],
      notifications: <InAppNotificationItem>[],
    );
  }

  final results = await Future.wait<dynamic>([
    ref.read(questsRepositoryProvider).getSubmittedForReview(family.familyId),
    ref.read(questsRepositoryProvider).getParentQuests(family.familyId),
    ref.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
    ref
        .read(notificationsRepositoryProvider)
        .listFamilyNotifications(family.familyId),
  ]);

  return ParentShellData(
    family: family,
    reviews: results[0] as List<ParentReviewItem>,
    quests: results[1] as List<ParentQuestItem>,
    wallets: results[2] as List<ParentChildWalletItem>,
    notifications: results[3] as List<InAppNotificationItem>,
  );
});

/// Данные главного экрана ребёнка.
class ChildShellData {
  const ChildShellData({
    required this.walletBalance,
    required this.activeAssignments,
    required this.exchangeCount,
    required this.completedCount,
    required this.goalCurrent,
    required this.goalTarget,
    required this.goalProgress,
  });

  final int walletBalance;
  final int activeAssignments;
  final int exchangeCount;
  final int completedCount;
  final int goalCurrent;
  final int goalTarget;
  final double goalProgress;
}

final childShellDataProvider = FutureProvider<ChildShellData>((ref) async {
  final session = await ref.watch(childSessionProvider.future);
  if (session == null) {
    return const ChildShellData(
      walletBalance: 0,
      activeAssignments: 0,
      exchangeCount: 0,
      completedCount: 0,
      goalCurrent: 0,
      goalTarget: 10000,
      goalProgress: 0,
    );
  }

  final wallet = await ref
      .read(walletRepositoryProvider)
      .getChildWallet(session.childId);
  final list = await ref
      .read(questsRepositoryProvider)
      .getChildAssignments(session.childId);

  final active = list
      .where(
        (a) =>
            a.distributionType != 'exchange' &&
            !isChildAssignmentCompleted(a) &&
            a.status != 'submitted',
      )
      .length;
  final exchange =
      list.where((a) => a.distributionType == 'exchange').length;
  final done = wallet?.completedQuestsCount ?? 0;
  final balance = wallet?.balance ?? 0;
  final rawGoal = wallet?.goalAmount ?? 10000;
  final goal = rawGoal > 0 ? rawGoal : 10000;

  return ChildShellData(
    walletBalance: balance,
    activeAssignments: active,
    exchangeCount: exchange,
    completedCount: done,
    goalCurrent: balance,
    goalTarget: goal,
    goalProgress: balance / goal,
  );
});
