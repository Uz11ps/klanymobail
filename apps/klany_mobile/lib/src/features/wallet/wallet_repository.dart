import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(),
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
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<WalletSummary?> getChildWallet(String childId) async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('wallets')
        .select('id, balance')
        .eq('child_id', childId)
        .maybeSingle();
    if (row == null) return null;
    return WalletSummary(
      walletId: row['id'].toString(),
      balance: (row['balance'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<WalletTxItem>> getWalletTransactions(String walletId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('transactions')
        .select('id, amount, tx_type, note, created_at')
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => WalletTxItem(
            id: row['id'].toString(),
            amount: (row['amount'] as num?)?.toInt() ?? 0,
            type: (row['tx_type'] ?? '').toString(),
            note: (row['note'] ?? '').toString(),
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                    DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<ParentChildWalletItem>> getFamilyWallets(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final children = await client
        .from('children')
        .select('id, display_name')
        .eq('family_id', familyId)
        .order('display_name');

    final result = <ParentChildWalletItem>[];
    for (final raw in (children as List<dynamic>)) {
      final child = raw as Map<String, dynamic>;
      final wallet = await client
          .from('wallets')
          .select('balance')
          .eq('child_id', child['id'].toString())
          .maybeSingle();
      result.add(
        ParentChildWalletItem(
          childId: child['id'].toString(),
          displayName: (child['display_name'] ?? '').toString(),
          balance: (wallet?['balance'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> adjustWallet({
    required String childId,
    required int amount,
    required String note,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_adjust_wallet',
      params: <String, dynamic>{
        'p_child_id': childId,
        'p_amount': amount,
        'p_note': note.trim().isEmpty ? 'Корректировка' : note.trim(),
      },
    );
  }
}

