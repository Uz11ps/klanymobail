import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import '../auth/child_session.dart';
import '../auth/parent_session.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref),
);

class WalletSummary {
  WalletSummary({
    required this.walletId,
    required this.balance,
  });

  final String walletId;
  final int balance;
}

class WalletTxItem {
  WalletTxItem({
    required this.id,
    required this.amount,
    required this.type,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final int amount;
  final String type;
  final String note;
  final DateTime createdAt;
}

class ParentChildWalletItem {
  ParentChildWalletItem({
    required this.childId,
    required this.displayName,
    required this.balance,
  });

  final String childId;
  final String displayName;
  final int balance;
}

class WalletRepository {
  WalletRepository(this.ref);
  final Ref ref;

  String? get _parentToken =>
      ref.read(parentSessionProvider).asData?.value?.accessToken;
  String? get _childToken =>
      ref.read(childSessionProvider).asData?.value?.accessToken;

  Future<WalletSummary?> getChildWallet(String childId) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return null;
    final data = await api.getJson('/wallet/child', accessToken: token);
    return WalletSummary(
      walletId: (data['walletId'] ?? '').toString(),
      balance: (data['balance'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<WalletTxItem>> getWalletTransactions(String walletId) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return const [];
    final data =
        await api.getJson('/wallet/child/transactions', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows.map((row) {
      return WalletTxItem(
        id: row['id'].toString(),
        amount: (row['amount'] as num?)?.toInt() ?? 0,
        type: (row['txType'] ?? '').toString(),
        note: (row['note'] ?? '').toString(),
        createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<List<ParentChildWalletItem>> getFamilyWallets(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/wallet/family', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows
        .map(
          (row) => ParentChildWalletItem(
            childId: row['childId'].toString(),
            displayName: (row['displayName'] ?? '').toString(),
            balance: (row['balance'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> adjustWallet({
    required String childId,
    required int amount,
    required String note,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/wallet/adjust',
      accessToken: token,
      body: <String, dynamic>{
        'childId': childId,
        'amount': amount,
        'note': note.trim().isEmpty ? 'Корректировка' : note.trim(),
      },
    );
  }
}

