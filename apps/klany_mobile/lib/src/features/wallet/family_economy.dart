import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/parent_access_repository.dart';

const int kDefaultRublesPer10Coins = 100;
const double kDefaultGlobalTaxRate = 0.2;

int coinsToRubles(int coins, int rublesPer10Coins) {
  return coins * rublesPer10Coins ~/ 10;
}

/// Монеты ребёнку после глобального налога (gross=100, tax=0.5 → 50).
int netQuestReward(int grossReward, double globalTaxRate) {
  final gross = grossReward < 0 ? 0 : grossReward;
  final rate = globalTaxRate.clamp(0.0, 0.5);
  return (gross * (1 - rate)).floor();
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

class FamilyGlobalTaxNotifier extends Notifier<double> {
  Timer? _saveTimer;

  @override
  double build() {
    ref.onDispose(() => _saveTimer?.cancel());
    ref.listen<AsyncValue<ParentFamilyContext?>>(
      parentFamilyContextProvider,
      (_, next) {
        final rate = next.asData?.value?.globalTaxRate;
        if (rate != null && rate != state) {
          state = rate.clamp(0.0, 0.5);
        }
      },
    );
    final fromContext =
        ref.watch(parentFamilyContextProvider).asData?.value?.globalTaxRate;
    return (fromContext ?? kDefaultGlobalTaxRate).clamp(0.0, 0.5);
  }

  void setTaxRate(double taxRate, {bool persist = true}) {
    final clamped = taxRate.clamp(0.0, 0.5);
    state = clamped;
    if (!persist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () async {
      await ref
          .read(parentAccessRepositoryProvider)
          .setFamilyGlobalTaxRate(clamped);
      ref.invalidate(parentFamilyContextProvider);
    });
  }
}

final familyGlobalTaxProvider =
    NotifierProvider<FamilyGlobalTaxNotifier, double>(
  FamilyGlobalTaxNotifier.new,
);
