import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/sdk.dart';
import '../auth/child_session.dart';
import '../auth/parent_session.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(ref),
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
  static const _uuid = Uuid();

  ShopRepository(this.ref);
  final Ref ref;

  String? get _parentToken =>
      ref.read(parentSessionProvider).asData?.value?.accessToken;
  String? get _childToken =>
      ref.read(childSessionProvider).asData?.value?.accessToken;

  Future<List<ShopProductItem>> getProducts(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken ?? _childToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/shop/products', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows
        .map(
          (row) => ShopProductItem(
            id: row['id'].toString(),
            title: (row['title'] ?? '').toString(),
            description: row['description']?.toString(),
            price: (row['price'] as num?)?.toInt() ?? 0,
            imagePath: row['imageKey']?.toString(),
            isActive: row['isActive'] == true,
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
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) throw Exception('API не настроен');

    String? imageKey;
    if (imageFile != null) {
      final Uint8List bytes = await imageFile.readAsBytes();
      final key = 'shop/${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}.jpg';
      final presign = await api.postJson(
        '/storage/presign-upload',
        accessToken: token,
        body: <String, dynamic>{'bucket': 'shop-products', 'objectKey': key},
      );
      final url = presign['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        await http.put(Uri.parse(url),
            headers: <String, String>{'Content-Type': 'image/jpeg'}, body: bytes);
        imageKey = key;
      }
    }

    await api.postJson(
      '/shop/products',
      accessToken: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'price': price,
        'imageKey': imageKey,
      },
    );
  }

  Future<void> toggleProduct(String productId, bool next) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/shop/products/$productId/toggle',
      accessToken: token,
      body: <String, dynamic>{'isActive': next},
    );
  }

  Future<void> requestPurchase(String productId) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/shop/purchases/request',
      accessToken: token,
      body: <String, dynamic>{'productId': productId, 'quantity': 1},
    );
  }

  Future<List<ShopPurchaseItem>> getPendingPurchases(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/shop/purchases/pending', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows
        .map(
          (row) => ShopPurchaseItem(
            id: row['id'].toString(),
            productTitle: (row['productTitle'] ?? '').toString(),
            childName: (row['childName'] ?? '').toString(),
            totalPrice: (row['totalPrice'] as num?)?.toInt() ?? 0,
            status: (row['status'] ?? '').toString(),
          ),
        )
        .toList();
  }

  Future<void> decidePurchase(String purchaseId, bool approve) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/shop/purchases/$purchaseId/decide',
      accessToken: token,
      body: <String, dynamic>{'approve': approve},
    );
  }
}

