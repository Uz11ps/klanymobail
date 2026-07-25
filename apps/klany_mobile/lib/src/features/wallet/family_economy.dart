import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/parent_access_repository.dart';

const int kDefaultRublesPer10Coins = 100;

int coinsToRubles(int coins, int rublesPer10Coins) {
  return coins * rublesPer10Coins ~/ 10;
}

class FamilyCoinRateNotifier extends Notifier<int> {
  @override
  int build() {
    ref.listen<AsyncValue<ParentFamilyContext?>>(
      parentFamilyContextProvider,
      (_, next) {
        final rate = next.asData?.value?.rublesPer10Coins;
        if (rate != null && rate > 0 && rate != state) {
          state = rate;
        }
      },
    );
    final fromContext =
        ref.watch(parentFamilyContextProvider).asData?.value?.rublesPer10Coins;
    return (fromContext != null && fromContext > 0)
        ? fromContext
        : kDefaultRublesPer10Coins;
  }

  Future<void> setRate(int rublesPer10Coins) async {
    if (rublesPer10Coins <= 0) return;
    await ref
        .read(parentAccessRepositoryProvider)
        .setFamilyCoinRate(rublesPer10Coins);
    state = rublesPer10Coins;
    ref.invalidate(parentFamilyContextProvider);
  }
}

final familyCoinRateProvider =
    NotifierProvider<FamilyCoinRateNotifier, int>(FamilyCoinRateNotifier.new);
