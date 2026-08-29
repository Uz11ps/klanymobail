import '../features/auth/parent_access_repository.dart';
import '../features/notifications/notifications_repository.dart';
import '../features/quests/quests_repository.dart';
import '../features/shop/shop_repository.dart';
import '../features/wallet/wallet_repository.dart';

bool sameParentFamilyContext(ParentFamilyContext? a, ParentFamilyContext? b) {
  if (a == null || b == null) return a == b;
  return a.familyId == b.familyId &&
      a.familyCode == b.familyCode &&
      (a.clanName ?? '') == (b.clanName ?? '') &&
      a.goalAmount == b.goalAmount &&
      (a.goalName ?? '') == (b.goalName ?? '') &&
      a.familySavingsTotal == b.familySavingsTotal &&
      a.rublesPer10Coins == b.rublesPer10Coins &&
      a.globalTaxRate == b.globalTaxRate;
}

bool sameParentWallets(
  List<ParentChildWalletItem> a,
  List<ParentChildWalletItem> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.childId != y.childId ||
        x.displayName != y.displayName ||
        x.balance != y.balance) {
      return false;
    }
  }
  return true;
}

bool sameParentReviews(List<ParentReviewItem> a, List<ParentReviewItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.questId != y.questId ||
        x.childId != y.childId ||
        x.childName != y.childName ||
        x.title != y.title ||
        x.submittedAt != y.submittedAt ||
        x.evidencePath != y.evidencePath ||
        x.evidenceUrl != y.evidenceUrl) {
      return false;
    }
  }
  return true;
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool sameParentQuests(List<ParentQuestItem> a, List<ParentQuestItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id ||
        x.title != y.title ||
        x.status != y.status ||
        x.questType != y.questType ||
        x.rewardAmount != y.rewardAmount ||
        x.createdAt != y.createdAt ||
        x.distributionType != y.distributionType ||
        x.autoApprove != y.autoApprove ||
        x.timeLimitMinutes != y.timeLimitMinutes ||
        x.scheduleType != y.scheduleType ||
        !_sameStrings(x.scheduleDays, y.scheduleDays)) {
      return false;
    }
  }
  return true;
}

bool sameFamilyNotifications(
  List<InAppNotificationItem> a,
  List<InAppNotificationItem> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id ||
        x.type != y.type ||
        x.status != y.status ||
        x.createdAt != y.createdAt ||
        x.payload.toString() != y.payload.toString()) {
      return false;
    }
  }
  return true;
}

bool sameShopProducts(List<ShopProductItem> a, List<ShopProductItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id ||
        x.title != y.title ||
        x.price != y.price ||
        x.isActive != y.isActive ||
        x.description != y.description ||
        x.imagePath != y.imagePath ||
        x.imageUrl != y.imageUrl) {
      return false;
    }
  }
  return true;
}

bool sameFamilyChildren(List<FamilyChildLite> a, List<FamilyChildLite> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id ||
        x.displayName != y.displayName ||
        x.avatarObjectKey != y.avatarObjectKey ||
        x.avatarImageUrl != y.avatarImageUrl) {
      return false;
    }
  }
  return true;
}
