import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import '../auth/parent_session.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref),
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
  SubscriptionRepository(this.ref);
  final Ref ref;

  String? get _token =>
      ref.read(parentSessionProvider).asData?.value?.accessToken;

  Future<List<FamilySubscriptionItem>> getFamilySubscriptions(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/subscriptions', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows.map((row) {
      return FamilySubscriptionItem(
        planCode: (row['planCode'] ?? '').toString(),
        status: (row['status'] ?? '').toString(),
        startedAt:
            DateTime.tryParse((row['startedAt'] ?? '').toString()) ?? DateTime.now(),
        expiresAt: DateTime.tryParse((row['expiresAt'] ?? '').toString()),
        source: (row['source'] ?? '').toString(),
      );
    }).toList();
  }

  Future<void> activatePromo(String code) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson(
      '/subscriptions/promo/activate',
      accessToken: token,
      body: <String, dynamic>{'code': code.trim()},
    );
  }

  Future<String> createPaymentOrder({
    required String planCode,
    required double amountRub,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('API не настроен');
    final data = await api.postJson(
      '/payments/orders',
      accessToken: token,
      body: <String, dynamic>{
        'planCode': planCode,
        'amountRub': amountRub,
      },
    );
    return (data['orderId'] ?? '').toString();
  }

  Future<String?> createYookassaCheckoutUrl(String orderId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return null;
    final data = await api.postJson(
      '/payments/yookassa/create-payment',
      accessToken: token,
      body: <String, dynamic>{'orderId': orderId},
    );
    return data['confirmationUrl']?.toString();
  }
}

