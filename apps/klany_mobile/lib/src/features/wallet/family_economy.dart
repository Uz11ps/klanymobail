import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/parent_access_repository.dart';

const int kDefaultRublesPer10Coins = 100;
const double kDefaultGlobalTaxRate = 0.2;
const int kGlobalTaxSegments = 8;

/// Доля налога по сегментам слайдера (0–8 → 0–50%).
double snapGlobalTaxRate(double taxRate) {
  final seg =
      ((taxRate.clamp(0.0, 0.5) / 0.5) * kGlobalTaxSegments).round().clamp(
        0,
        kGlobalTaxSegments,
      );
  return seg / kGlobalTaxSegments * 0.5;
}

/// Процент для подписи (совпадает с сегментами полоски).
int globalTaxPercentLabel(double taxRate) {
  final seg =
      ((snapGlobalTaxRate(taxRate) / 0.5) * kGlobalTaxSegments).round().clamp(
        0,
        kGlobalTaxSegments,
      );
  return ((seg / kGlobalTaxSegments) * 50).round();
}

int coinsToRubles(int coins, int rublesPer10Coins) {
  return coins * rublesPer10Coins ~/ 10;
}

/// Монеты ребёнку после глобального налога (gross=100, tax=0.5 → 50).
int netQuestReward(int grossReward, double globalTaxRate) {
  final gross = grossReward < 0 ? 0 : grossReward;
  final rate = snapGlobalTaxRate(globalTaxRate);
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
    await ref.read(parentFamilyContextProvider.notifier).refresh(force: true);
  }
}

final familyCoinRateProvider =
    NotifierProvider<FamilyCoinRateNotifier, int>(FamilyCoinRateNotifier.new);

class FamilyGlobalTaxNotifier extends Notifier<double> {
  Timer? _saveTimer;
  bool _serverPersistSupported = true;
  bool _seededFromServer = false;
  /// После drag UI не перезаписывается refetch context / live poll.
  bool _userControlled = false;

  @override
  double build() {
    ref.onDispose(() => _saveTimer?.cancel());
    ref.listen<AsyncValue<ParentFamilyContext?>>(
      parentFamilyContextProvider,
      (_, next) {
        if (_userControlled || _seededFromServer) return;
        final rate = next.asData?.value?.globalTaxRate;
        if (rate == null) return;
        _seededFromServer = true;
        state = snapGlobalTaxRate(rate);
      },
    );
    final fromContext =
        ref.read(parentFamilyContextProvider).asData?.value?.globalTaxRate;
    return snapGlobalTaxRate(fromContext ?? kDefaultGlobalTaxRate);
  }

  void setTaxRate(double taxRate, {bool persist = true}) {
    final clamped = snapGlobalTaxRate(taxRate);
    _userControlled = true;
    state = clamped;
    if (!persist || !_serverPersistSupported) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!ref.mounted) return;
      try {
        final saved = await ref
            .read(parentAccessRepositoryProvider)
            .setFamilyGlobalTaxRate(clamped);
        if (!saved) _serverPersistSupported = false;
      } on ApiException catch (e) {
        if (e.statusCode == 404) _serverPersistSupported = false;
      } catch (_) {}
    });
  }
}

final familyGlobalTaxProvider =
    NotifierProvider<FamilyGlobalTaxNotifier, double>(
  FamilyGlobalTaxNotifier.new,
);
