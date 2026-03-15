import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';

class AdminRepository {
  AdminRepository(this.client);

  final SupabaseClient? client;
  ApiClient get _api => ApiClient(Env.apiBaseUrl);

  bool get _ready => client != null;

  Future<List<Map<String, dynamic>>> readTable(
    String table, {
    required String columns,
    int limit = 200,
    String? orderBy,
    bool ascending = false,
    Map<String, dynamic>? eq,
    Map<String, List<dynamic>>? whereIn,
    Map<String, dynamic>? lte,
    Map<String, dynamic>? gte,
  }) async {
    final c = client;
    if (!_ready || c == null) return const [];

    // Apply filters first (filter builder), then select + transforms.
    dynamic q = c.from(table);
    if (eq != null) {
      for (final e in eq.entries) {
        q = q.eq(e.key, e.value);
      }
    }
    if (whereIn != null) {
      for (final e in whereIn.entries) {
        q = q.in_(e.key, e.value);
      }
    }
    if (lte != null) {
      for (final e in lte.entries) {
        q = q.lte(e.key, e.value);
      }
    }
    if (gte != null) {
      for (final e in gte.entries) {
        q = q.gte(e.key, e.value);
      }
    }

    q = q.select(columns).limit(limit);
    if (orderBy != null && orderBy.isNotEmpty) {
      q = q.order(orderBy, ascending: ascending);
    }

    final res = await q;
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ===== Queues =====
  Future<List<Map<String, dynamic>>> accessRequestsPending({
    required String accessToken,
    required String role,
  }) async {
    final path = role == 'parent'
        ? '/parent/access-requests'
        : '/admin/access-requests';
    final data = await _api.getJson(
      path,
      accessToken: accessToken,
      query: role == 'parent' ? null : const {'status': 'pending'},
    );
    final items = (data['items'] as List?) ?? const [];
    return items.whereType<Map>().map((row) {
      final m = Map<String, dynamic>.from(row);
      return <String, dynamic>{
        'id': (m['id'] ?? '').toString(),
        'family_id': (m['familyId'] ?? '').toString(),
        'child_first_name': (m['firstName'] ?? '').toString(),
        'child_last_name': (m['lastName'] ?? '').toString(),
        'device_id': (m['deviceId'] ?? '').toString(),
        'status': (m['status'] ?? '').toString(),
        'created_at': (m['createdAt'] ?? '').toString(),
      };
    }).toList();
  }

  Future<void> approveAccessRequest(
    String requestId, {
    required String accessToken,
    required String role,
  }) async {
    final path = role == 'parent'
        ? '/parent/access-requests/$requestId/approve'
        : '/admin/access-requests/$requestId/approve';
    await _api.postJson(path, accessToken: accessToken, body: const {});
  }

  Future<void> rejectAccessRequest(
    String requestId, {
    required String accessToken,
    required String role,
    String? reason,
  }) async {
    final path = role == 'parent'
        ? '/parent/access-requests/$requestId/reject'
        : '/admin/access-requests/$requestId/reject';
    await _api.postJson(
      path,
      accessToken: accessToken,
      body: {'reason': (reason ?? '').trim()},
    );
  }

  Future<Map<String, dynamic>> familyContext({
    required String accessToken,
  }) async {
    return _api.getJson('/family/context', accessToken: accessToken);
  }

  Future<List<Map<String, dynamic>>> parentMembers({
    required String accessToken,
  }) async {
    final data = await _api.getJson(
      '/parent/members',
      accessToken: accessToken,
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> parentChildren({
    required String accessToken,
  }) async {
    final data = await _api.getJson(
      '/parent/children',
      accessToken: accessToken,
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteChild({
    required String accessToken,
    required String role,
    required String childId,
  }) async {
    final path = role == 'parent'
        ? '/parent/children/$childId'
        : '/admin/children/$childId';
    await _api.deleteJson(path, accessToken: accessToken);
  }

  Future<List<Map<String, dynamic>>> adminChildren({
    required String accessToken,
  }) async {
    final data = await _api.getJson(
      '/admin/children',
      accessToken: accessToken,
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> updateChild({
    required String accessToken,
    required String role,
    required String childId,
    String? firstName,
    String? lastName,
    bool? isActive,
  }) async {
    final path = role == 'parent'
        ? '/parent/children/$childId'
        : '/admin/children/$childId';
    final body = <String, dynamic>{
      'firstName': firstName?.trim(),
      'lastName': lastName?.trim(),
      'isActive': isActive,
    }..removeWhere((_, value) => value == null);
    await _api.patchJson(path, accessToken: accessToken, body: body);
  }

  Future<List<Map<String, dynamic>>> adminProducts({
    required String accessToken,
  }) async {
    final data = await _api.getJson(
      '/admin/products',
      accessToken: accessToken,
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> updateProduct({
    required String accessToken,
    required String role,
    required String productId,
    String? title,
    String? description,
    int? price,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      'title': title?.trim(),
      'description': description?.trim(),
      'price': price,
      'isActive': isActive,
    }..removeWhere((_, value) => value == null);
    final path = role == 'parent'
        ? '/shop/products/$productId'
        : '/admin/products/$productId';
    await _api.patchJson(path, accessToken: accessToken, body: body);
  }

  Future<void> deleteProduct({
    required String accessToken,
    required String role,
    required String productId,
  }) async {
    final path = role == 'parent'
        ? '/shop/products/$productId'
        : '/admin/products/$productId';
    await _api.deleteJson(path, accessToken: accessToken);
  }

  Future<List<Map<String, dynamic>>> adminQuests({
    required String accessToken,
  }) async {
    final data = await _api.getJson('/admin/quests', accessToken: accessToken);
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> updateQuest({
    required String accessToken,
    required String role,
    required String questId,
    String? title,
    String? description,
    int? rewardAmount,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'title': title?.trim(),
      'rewardAmount': rewardAmount,
      'status': status?.trim(),
    }..removeWhere((_, value) => value == null);
    final path = role == 'parent'
        ? '/quests/$questId'
        : '/admin/quests/$questId';
    await _api.patchJson(path, accessToken: accessToken, body: body);
  }

  Future<void> deleteQuest({
    required String accessToken,
    required String role,
    required String questId,
  }) async {
    final path = role == 'parent'
        ? '/quests/$questId'
        : '/admin/quests/$questId';
    await _api.deleteJson(path, accessToken: accessToken);
  }

  Future<List<Map<String, dynamic>>> parentProducts({
    required String accessToken,
  }) async {
    final data = await _api.getJson('/shop/products', accessToken: accessToken);
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> parentQuests({
    required String accessToken,
  }) async {
    final data = await _api.getJson('/quests/parent', accessToken: accessToken);
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> purchasesRequested() => readTable(
    'shop_purchases',
    columns:
        'id, product_id, child_id, quantity, total_price, frozen_amount, status, created_at',
    eq: const {'status': 'requested'},
    orderBy: 'created_at',
  );

  Future<void> decidePurchase(String purchaseId, bool approve) async {
    final c = client;
    if (c == null) return;
    await c.rpc(
      'parent_decide_purchase',
      params: {'p_purchase_id': purchaseId, 'p_approve': approve},
    );
  }

  Future<List<Map<String, dynamic>>> questSubmissions() async {
    // Read "submitted" assignees + map quest/child names in two extra queries.
    final rows = await readTable(
      'quest_assignees',
      columns: 'quest_id, child_id, status, submitted_at, reward_amount',
      eq: const {'status': 'submitted'},
      orderBy: 'submitted_at',
    );
    if (rows.isEmpty) return rows;

    final questIds = rows
        .map((r) => r['quest_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final childIds = rows
        .map((r) => r['child_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final quests = questIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await readTable(
            'quests',
            columns: 'id, family_id, title',
            whereIn: {'id': questIds},
            limit: 200,
          );
    final children = childIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await readTable(
            'children',
            columns: 'id, family_id, display_name',
            whereIn: {'id': childIds},
            limit: 200,
          );

    final questById = {for (final q in quests) (q['id'] ?? '').toString(): q};
    final childById = {for (final c in children) (c['id'] ?? '').toString(): c};

    return rows.map((r) {
      final quest = questById[(r['quest_id'] ?? '').toString()];
      final child = childById[(r['child_id'] ?? '').toString()];
      return {
        ...r,
        'quest_title': quest?['title'],
        'quest_family_id': quest?['family_id'],
        'child_name': child?['display_name'],
        'child_family_id': child?['family_id'],
      };
    }).toList();
  }

  Future<void> reviewQuest({
    required String questId,
    required String childId,
    required bool approve,
    String? comment,
  }) async {
    final c = client;
    if (c == null) return;
    await c.rpc(
      'parent_review_quest_submission',
      params: {
        'p_quest_id': questId,
        'p_child_id': childId,
        'p_approve': approve,
        'p_comment': comment,
      },
    );
  }

  // ===== Promo / Subscriptions =====
  Future<List<Map<String, dynamic>>> promoCodes() => readTable(
    'promo_codes',
    columns:
        'id, code, plan_code, duration_days, max_uses, used_count, is_active, created_at',
    orderBy: 'created_at',
  );

  Future<void> createPromoCode({
    required String code,
    required String planCode,
    required int durationDays,
    required int maxUses,
  }) async {
    final c = client;
    if (c == null) return;
    await c.from('promo_codes').insert({
      'code': code.trim().toUpperCase(),
      'plan_code': planCode.trim(),
      'duration_days': durationDays,
      'max_uses': maxUses,
      'used_count': 0,
      'is_active': true,
    });
  }

  Future<void> setPromoActive(String promoId, bool active) async {
    final c = client;
    if (c == null) return;
    await c.from('promo_codes').update({'is_active': active}).eq('id', promoId);
  }

  Future<List<Map<String, dynamic>>> promoRedemptions({String? promoId}) =>
      readTable(
        'promo_redemptions',
        columns: 'id, promo_id, family_id, redeemed_at',
        orderBy: 'redeemed_at',
        eq: promoId == null ? null : {'promo_id': promoId},
      );

  Future<List<Map<String, dynamic>>> subscriptionsExpiringInDays(int days) {
    final now = DateTime.now().toUtc();
    final to = now.add(Duration(days: days));
    return readTable(
      'family_subscriptions',
      columns:
          'id, family_id, plan_code, status, expires_at, created_at, source',
      eq: const {'status': 'active'},
      lte: {'expires_at': to.toIso8601String()},
      gte: {'expires_at': now.toIso8601String()},
      orderBy: 'expires_at',
      ascending: true,
    );
  }

  // ===== Payments / Webhooks =====
  Future<List<Map<String, dynamic>>> paymentOrders({
    String? status,
  }) => readTable(
    'payment_orders',
    columns:
        'id, family_id, amount_rub, status, plan_code, provider_payment_id, created_at, paid_at',
    eq: status == null ? null : {'status': status},
    orderBy: 'created_at',
  );

  Future<List<Map<String, dynamic>>> webhookEvents({
    String? provider,
    bool? processed,
  }) async {
    final eq = <String, dynamic>{};
    if (provider != null && provider.isNotEmpty) eq['provider'] = provider;
    if (processed != null) eq['processed'] = processed;
    return readTable(
      'payment_webhook_events',
      columns: 'id, provider, event_type, event_id, processed, created_at',
      eq: eq.isEmpty ? null : eq,
      orderBy: 'created_at',
    );
  }

  // ===== Analytics =====
  Future<Map<String, dynamic>> adminCounts(String period) async {
    final c = client;
    if (c == null) return const {};
    final res = await c.rpc('admin_counts', params: {'p_period': period});
    return Map<String, dynamic>.from(res as Map);
  }

  // ===== Operations =====
  Future<void> setFamilyClanName({
    required String familyId,
    required String clanName,
  }) async {
    final c = client;
    if (c == null) return;
    await c
        .from('families')
        .update({'clan_name': clanName.trim()})
        .eq('id', familyId);
  }

  Future<void> setProfileRole({
    required String userId,
    required String role,
  }) async {
    final c = client;
    if (c == null) return;
    await c.from('profiles').update({'role': role}).eq('user_id', userId);
  }

  Future<void> setChildActive({
    required String childId,
    required bool isActive,
  }) async {
    final c = client;
    if (c == null) return;
    await c.from('children').update({'is_active': isActive}).eq('id', childId);
  }

  Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    final c = client;
    if (c == null) return;
    await c
        .from('shop_products')
        .update({'is_active': isActive})
        .eq('id', productId);
  }

  Future<void> cancelSubscription({required String subscriptionId}) async {
    final c = client;
    if (c == null) return;
    await c
        .from('family_subscriptions')
        .update({'status': 'canceled'})
        .eq('id', subscriptionId);
  }

  Future<void> deletePromoCode(String promoId) async {
    final c = client;
    if (c == null) return;
    await c.from('promo_codes').delete().eq('id', promoId);
  }

  // ===== Admin accounts =====
  Future<List<Map<String, dynamic>>> adminAccounts({
    required String accessToken,
  }) async {
    final data = await _api.getJson(
      '/admin/admin-accounts',
      accessToken: accessToken,
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> createAdminAccount({
    required String accessToken,
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _api.postJson(
      '/admin/admin-accounts',
      accessToken: accessToken,
      body: {
        'email': email.trim(),
        'password': password,
        'displayName': (displayName ?? '').trim(),
      },
    );
  }

  Future<void> deleteAdminAccount({
    required String accessToken,
    required String userId,
  }) async {
    await _api.deleteJson(
      '/admin/admin-accounts/$userId',
      accessToken: accessToken,
    );
  }
}
