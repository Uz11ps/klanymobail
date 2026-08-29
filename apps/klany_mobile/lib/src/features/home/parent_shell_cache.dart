import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/parent_data_equality.dart';
import '../auth/parent_access_repository.dart';
import '../notifications/notifications_repository.dart';
import '../quests/quests_repository.dart';
import '../shop/shop_repository.dart';
import '../wallet/wallet_repository.dart';

/// Кэш данных родительского shell: один prefetch, обновление только при diff.
class ParentShellCache {
  const ParentShellCache({
    required this.family,
    required this.wallets,
    required this.reviews,
    required this.quests,
    required this.notifications,
    required this.shopProducts,
    required this.familyChildren,
  });

  static const empty = ParentShellCache(
    family: null,
    wallets: <ParentChildWalletItem>[],
    reviews: <ParentReviewItem>[],
    quests: <ParentQuestItem>[],
    notifications: <InAppNotificationItem>[],
    shopProducts: <ShopProductItem>[],
    familyChildren: <FamilyChildLite>[],
  );

  final ParentFamilyContext? family;
  final List<ParentChildWalletItem> wallets;
  final List<ParentReviewItem> reviews;
  final List<ParentQuestItem> quests;
  final List<InAppNotificationItem> notifications;
  final List<ShopProductItem> shopProducts;
  final List<FamilyChildLite> familyChildren;
}

bool sameParentShellCache(ParentShellCache a, ParentShellCache b) {
  return sameParentFamilyContext(a.family, b.family) &&
      sameParentWallets(a.wallets, b.wallets) &&
      sameParentReviews(a.reviews, b.reviews) &&
      sameParentQuests(a.quests, b.quests) &&
      sameFamilyNotifications(a.notifications, b.notifications) &&
      sameShopProducts(a.shopProducts, b.shopProducts) &&
      sameFamilyChildren(a.familyChildren, b.familyChildren);
}

class ParentShellCacheNotifier extends AsyncNotifier<ParentShellCache> {
  @override
  Future<ParentShellCache> build() async {
    ref.keepAlive();
    return _fetch();
  }

  Future<ParentShellCache> _fetch() async {
    final family =
        await ref.read(parentAccessRepositoryProvider).getFamilyContext();
    if (family == null) return ParentShellCache.empty;

    final results = await Future.wait<dynamic>([
      ref.read(questsRepositoryProvider).getSubmittedForReview(family.familyId),
      ref.read(questsRepositoryProvider).getParentQuests(family.familyId),
      ref.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
      ref
          .read(notificationsRepositoryProvider)
          .listFamilyNotifications(family.familyId),
      ref.read(shopRepositoryProvider).getProducts(family.familyId),
      ref.read(questsRepositoryProvider).getFamilyChildren(family.familyId),
    ]);

    return ParentShellCache(
      family: family,
      reviews: results[0] as List<ParentReviewItem>,
      quests: results[1] as List<ParentQuestItem>,
      wallets: results[2] as List<ParentChildWalletItem>,
      notifications: results[3] as List<InAppNotificationItem>,
      shopProducts: results[4] as List<ShopProductItem>,
      familyChildren: results[5] as List<FamilyChildLite>,
    );
  }

  /// Тихое обновление: state меняется только если данные реально другие.
  Future<void> refresh({bool force = false}) async {
    try {
      final next = await _fetch();
      final prev = state.asData?.value;
      if (!force && prev != null && sameParentShellCache(prev, next)) return;
      state = AsyncData(next);
    } catch (e, st) {
      if (state.asData == null) state = AsyncError(e, st);
    }
  }
}

final parentShellCacheProvider =
    AsyncNotifierProvider<ParentShellCacheNotifier, ParentShellCache>(
  ParentShellCacheNotifier.new,
);

/// Фоновый prefetch при входе в shell — без блокировки UI.
void prefetchParentShellCache(WidgetRef ref) {
  ref.read(parentFamilyContextProvider.notifier).refresh();
  ref.read(parentShellCacheProvider.notifier).refresh();
}

void refreshParentShellCache(WidgetRef ref, {bool force = false}) {
  ref.read(parentFamilyContextProvider.notifier).refresh(force: force);
  ref.read(parentShellCacheProvider.notifier).refresh(force: force);
}
