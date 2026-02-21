import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(),
);

class FamilySubscriptionItem {
  FamilySubscriptionItem({
    required this.planCode,
    required this.status,
    required this.startedAt,
    this.expiresAt,
    required this.source,
  });

  final String planCode;
  final String status;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final String source;
}

class SubscriptionRepository {
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<List<FamilySubscriptionItem>> getFamilySubscriptions(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('family_subscriptions')
        .select('plan_code, status, started_at, expires_at, source')
        .eq('family_id', familyId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => FamilySubscriptionItem(
            planCode: (row['plan_code'] ?? '').toString(),
            status: (row['status'] ?? '').toString(),
            startedAt:
                DateTime.tryParse((row['started_at'] ?? '').toString()) ??
                    DateTime.now(),
            expiresAt: DateTime.tryParse((row['expires_at'] ?? '').toString()),
            source: (row['source'] ?? '').toString(),
          ),
        )
        .toList();
  }

  Future<void> activatePromo(String code) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_activate_promo',
      params: <String, dynamic>{'p_code': code.trim()},
    );
  }

  Future<String> createPaymentOrder({
    required String planCode,
    required double amountRub,
  }) async {
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');
    final response = await client.rpc(
      'parent_create_payment_order',
      params: <String, dynamic>{
        'p_plan_code': planCode,
        'p_amount_rub': amountRub,
      },
    );
    return response.toString();
  }

  Future<String?> createYookassaCheckoutUrl(String orderId) async {
    final client = _client;
    if (client == null) return null;
    final result = await client.functions.invoke(
      'yookassa-create-payment',
      body: <String, dynamic>{'orderId': orderId},
    );
    final data = result.data;
    if (data is Map<String, dynamic>) {
      return data['confirmationUrl']?.toString();
    }
    return null;
  }
}

