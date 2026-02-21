import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/sdk.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(),
);

class ShopProductItem {
  ShopProductItem({
    required this.id,
    required this.title,
    required this.price,
    required this.isActive,
    this.description,
    this.imagePath,
  });

  final String id;
  final String title;
  final int price;
  final bool isActive;
  final String? description;
  final String? imagePath;
}

class ShopPurchaseItem {
  ShopPurchaseItem({
    required this.id,
    required this.productTitle,
    required this.childName,
    required this.totalPrice,
    required this.status,
  });

  final String id;
  final String productTitle;
  final String childName;
  final int totalPrice;
  final String status;
}

class ShopRepository {
  static const _productsBucket = 'shop-products';
  static const _uuid = Uuid();

  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<List<ShopProductItem>> getProducts(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('shop_products')
        .select('id, title, description, price, image_path, is_active')
        .eq('family_id', familyId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => ShopProductItem(
            id: row['id'].toString(),
            title: (row['title'] ?? '').toString(),
            description: row['description']?.toString(),
            price: (row['price'] as num?)?.toInt() ?? 0,
            imagePath: row['image_path']?.toString(),
            isActive: row['is_active'] == true,
          ),
        )
        .toList();
  }

  Future<void> createProduct({
    required String title,
    required String description,
    required int price,
    required XFile? imageFile,
  }) async {
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');
    String? imagePath;
    if (imageFile != null) {
      final Uint8List bytes = await imageFile.readAsBytes();
      final path = 'shop/${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}.jpg';
      await client.storage.from(_productsBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );
      imagePath = path;
    }

    await client.rpc(
      'parent_create_shop_product',
      params: <String, dynamic>{
        'p_title': title.trim(),
        'p_description': description.trim().isEmpty ? null : description.trim(),
        'p_price': price,
        'p_image_path': imagePath,
      },
    );
  }

  Future<void> toggleProduct(String productId, bool next) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('shop_products')
        .update(<String, dynamic>{'is_active': next})
        .eq('id', productId);
  }

  Future<void> requestPurchase(String productId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'child_request_purchase',
      params: <String, dynamic>{
        'p_product_id': productId,
        'p_quantity': 1,
      },
    );
  }

  Future<List<ShopPurchaseItem>> getPendingPurchases(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('shop_purchases')
        .select('id, total_price, status, shop_products(title), children(display_name, family_id)')
        .eq('status', 'requested')
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .where((row) {
      final child = row['children'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return child['family_id']?.toString() == familyId;
    })
        .map((row) {
      final product = row['shop_products'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final child = row['children'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return ShopPurchaseItem(
        id: row['id'].toString(),
        productTitle: (product['title'] ?? '').toString(),
        childName: (child['display_name'] ?? '').toString(),
        totalPrice: (row['total_price'] as num?)?.toInt() ?? 0,
        status: (row['status'] ?? '').toString(),
      );
    }).toList();
  }

  Future<void> decidePurchase(String purchaseId, bool approve) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_decide_purchase',
      params: <String, dynamic>{
        'p_purchase_id': purchaseId,
        'p_approve': approve,
      },
    );
  }
}

