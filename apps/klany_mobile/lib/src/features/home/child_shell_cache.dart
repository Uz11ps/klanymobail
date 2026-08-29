import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/child_data_equality.dart';
import '../../core/parent_data_equality.dart';
import '../auth/child_session.dart';
import '../quests/quests_repository.dart';
import '../shop/shop_repository.dart';
import '../wallet/wallet_repository.dart';

/// Кэш данных детского shell — prefetch + diff-only refresh.
class ChildShellCache {
  const ChildShellCache({
    required this.walletBalance,
    required this.activeAssignments,
    required this.exchangeCount,
    required this.completedCount,
    required this.goalCurrent,
    required this.goalTarget,
    required this.goalProgress,
    this.goalName,
    required this.assignments,
    required this.shopProducts,
    required this.shopFrozenAmount,
    required this.pendingPurchasesByProductId,
  });

  static const empty = ChildShellCache(
    walletBalance: 0,
    activeAssignments: 0,
    exchangeCount: 0,
    completedCount: 0,
    goalCurrent: 0,
    goalTarget: 10000,
    goalProgress: 0,
    goalName: null,
    assignments: <ChildQuestAssignmentItem>[],
    shopProducts: <ShopProductItem>[],
    shopFrozenAmount: 0,
    pendingPurchasesByProductId: <String, ChildShopPurchaseItem>{},
  );

  final int walletBalance;
  final int activeAssignments;
  final int exchangeCount;
  final int completedCount;
  final int goalCurrent;
  final int goalTarget;
  final double goalProgress;
  final String? goalName;
  final List<ChildQuestAssignmentItem> assignments;
  final List<ShopProductItem> shopProducts;
  final int shopFrozenAmount;
  final Map<String, ChildShopPurchaseItem> pendingPurchasesByProductId;
}

bool sameChildShellCache(ChildShellCache a, ChildShellCache b) {
  return sameChildShellOverview(
        walletBalanceA: a.walletBalance,
        activeA: a.activeAssignments,
        exchangeA: a.exchangeCount,
        completedA: a.completedCount,
        goalCurrentA: a.goalCurrent,
        goalTargetA: a.goalTarget,
        goalProgressA: a.goalProgress,
        goalNameA: a.goalName,
        walletBalanceB: b.walletBalance,
        activeB: b.activeAssignments,
        exchangeB: b.exchangeCount,
        completedB: b.completedCount,
        goalCurrentB: b.goalCurrent,
        goalTargetB: b.goalTarget,
        goalProgressB: b.goalProgress,
        goalNameB: b.goalName,
      ) &&
      sameChildAssignments(a.assignments, b.assignments) &&
      sameShopProducts(a.shopProducts, b.shopProducts) &&
      a.shopFrozenAmount == b.shopFrozenAmount &&
      sameChildPendingPurchases(
        a.pendingPurchasesByProductId,
        b.pendingPurchasesByProductId,
      );
}

ChildShellCache _buildCacheFrom({
  required WalletSummary? wallet,
  required List<ChildQuestAssignmentItem> assignments,
  required List<ShopProductItem> shopProducts,
  required Map<String, ChildShopPurchaseItem> pendingPurchases,
}) {
  final active = assignments
      .where(
        (a) =>
            a.distributionType != 'exchange' &&
            !isChildAssignmentCompleted(a) &&
            a.status != 'submitted',
      )
      .length;
  final exchange =
      assignments.where((a) => a.distributionType == 'exchange').length;
  final done = wallet?.completedQuestsCount ?? 0;
  final balance = wallet?.balance ?? 0;
  final rawGoal = wallet?.goalAmount ?? 10000;
  final goal = rawGoal > 0 ? rawGoal : 10000;
  final savings = wallet?.familySavingsTotal ?? balance;
  final goalName = wallet?.goalName;

  return ChildShellCache(
    walletBalance: balance,
    activeAssignments: active,
    exchangeCount: exchange,
    completedCount: done,
    goalCurrent: savings,
    goalTarget: goal,
    goalProgress: goal > 0 ? savings / goal : 0,
    goalName: goalName,
    assignments: assignments,
    shopProducts: shopProducts,
    shopFrozenAmount: wallet?.shopFrozenAmount ?? 0,
    pendingPurchasesByProductId: pendingPurchases,
  );
}

class ChildShellCacheNotifier extends AsyncNotifier<ChildShellCache> {
  @override
  Future<ChildShellCache> build() async {
    ref.keepAlive();
    return _fetch();
  }

  Future<ChildShellCache> _fetch() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return ChildShellCache.empty;

    final shopRepo = ref.read(shopRepositoryProvider);
    final productsFuture = shopRepo.getProducts(session.familyId);
    final walletFuture = ref
        .read(walletRepositoryProvider)
        .getChildWallet(session.childId);
    final assignmentsFuture = ref
        .read(questsRepositoryProvider)
        .getChildAssignments(session.childId);

    WalletSummary? wallet;
    var purchases = const <ChildShopPurchaseItem>[];
    try {
      wallet = await walletFuture;
    } catch (_) {}
    try {
      purchases = await shopRepo.getChildPurchases();
    } catch (_) {}

    final products = await productsFuture;
    final assignments = await assignmentsFuture;
    final pending = <String, ChildShopPurchaseItem>{
      for (final p in purchases.where((p) => p.isPending)) p.productId: p,
    };

    return _buildCacheFrom(
      wallet: wallet,
      assignments: assignments,
      shopProducts: products,
      pendingPurchases: pending,
    );
  }

  Future<void> refresh({bool force = false}) async {
    try {
      final next = await _fetch();
      final prev = state.asData?.value;
      if (!force && prev != null && sameChildShellCache(prev, next)) return;
      state = AsyncData(next);
    } catch (e, st) {
      if (state.asData == null) state = AsyncError(e, st);
    }
  }
}

final childShellCacheProvider =
    AsyncNotifierProvider<ChildShellCacheNotifier, ChildShellCache>(
  ChildShellCacheNotifier.new,
);

void prefetchChildShellCache(WidgetRef ref) {
  ref.read(childShellCacheProvider.notifier).refresh();
}

void refreshChildShellCache(WidgetRef ref, {bool force = false}) {
  ref.read(childShellCacheProvider.notifier).refresh(force: force);
}
