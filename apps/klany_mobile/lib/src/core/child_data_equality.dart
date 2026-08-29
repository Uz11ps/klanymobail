import '../features/quests/quests_repository.dart';
import '../features/shop/shop_repository.dart';

bool sameChildAssignments(
  List<ChildQuestAssignmentItem> a,
  List<ChildQuestAssignmentItem> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.questId != y.questId ||
        x.assignmentId != y.assignmentId ||
        x.title != y.title ||
        x.status != y.status ||
        x.rewardAmount != y.rewardAmount ||
        x.distributionType != y.distributionType ||
        x.autoApprove != y.autoApprove ||
        x.timeLimitMinutes != y.timeLimitMinutes ||
        x.scheduleType != y.scheduleType ||
        x.comment != y.comment ||
        x.dueAt != y.dueAt ||
        x.createdAt != y.createdAt ||
        !_sameStringList(x.scheduleDays, y.scheduleDays)) {
      return false;
    }
  }
  return true;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool sameChildPendingPurchases(
  Map<String, ChildShopPurchaseItem> a,
  Map<String, ChildShopPurchaseItem> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final y = b[entry.key];
    if (y == null) return false;
    final x = entry.value;
    if (x.id != y.id ||
        x.productId != y.productId ||
        x.productTitle != y.productTitle ||
        x.totalPrice != y.totalPrice ||
        x.status != y.status ||
        x.createdAt != y.createdAt ||
        x.decidedAt != y.decidedAt) {
      return false;
    }
  }
  return true;
}

bool sameChildShellOverview({
  required int walletBalanceA,
  required int activeA,
  required int exchangeA,
  required int completedA,
  required int goalCurrentA,
  required int goalTargetA,
  required double goalProgressA,
  String? goalNameA,
  required int walletBalanceB,
  required int activeB,
  required int exchangeB,
  required int completedB,
  required int goalCurrentB,
  required int goalTargetB,
  required double goalProgressB,
  String? goalNameB,
}) {
  return walletBalanceA == walletBalanceB &&
      activeA == activeB &&
      exchangeA == exchangeB &&
      completedA == completedB &&
      goalCurrentA == goalCurrentB &&
      goalTargetA == goalTargetB &&
      goalProgressA == goalProgressB &&
      (goalNameA ?? '') == (goalNameB ?? '');
}
