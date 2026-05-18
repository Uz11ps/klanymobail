import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
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
    this.imageUrl,
  });

  final String id;
  final String title;
  final int price;
  final bool isActive;
  final String? description;
  final String? imagePath;
  final String? imageUrl;
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

bool _parseBool(dynamic raw, {bool defaultIfMissing = false}) {
  if (raw == null) return defaultIfMissing;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final s = raw.toString().toLowerCase().trim();
  if (s.isEmpty) return defaultIfMissing;
  if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
  if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
  return defaultIfMissing;
}

class ShopRepository {
  static const _uuid = Uuid();

  ShopRepository(this.ref);
  final Ref ref;

  String? get _parentToken =>
      ref.read(parentSessionProvider).asData?.value?.accessToken;
  String? get _childToken =>
      ref.read(childSessionProvider).asData?.value?.accessToken;

  Future<String?> _presignDownloadUrl({
    required String token,
    required String bucket,
    required String objectKey,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null || objectKey.trim().isEmpty) return null;
    try {
      final res = await api.postJson(
        '/storage/presign-download',
        accessToken: token,
        body: <String, dynamic>{
          'bucket': bucket,
          'objectKey': objectKey,
          'expiresSeconds': 3600,
        },
      );
      final url = res['url']?.toString();
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<List<ShopProductItem>> getProducts(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken ?? _childToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/shop/products', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return Future.wait(
      rows.map((row) async {
        final imagePath = row['imageKey']?.toString();
        final imageUrl = (imagePath != null && imagePath.isNotEmpty)
            ? await _presignDownloadUrl(
                token: token,
                bucket: 'shop-products',
                objectKey: imagePath,
              )
            : null;
        return ShopProductItem(
          id: row['id'].toString(),
          title: (row['title'] ?? '').toString(),
          description: row['description']?.toString(),
          price: (row['price'] as num?)?.toInt() ?? 0,
          imagePath: imagePath,
          imageUrl: imageUrl,
          // Default to true so newly created items always show up on the kid
          // side; the backend filters by family/availability anyway.
          isActive: _parseBool(row['isActive'], defaultIfMissing: true),
        );
      }),
    );
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
      final key =
          'shop/${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}.jpg';
      final presign = await api.postJson(
        '/storage/presign-upload',
        accessToken: token,
        body: <String, dynamic>{'bucket': 'shop-products', 'objectKey': key},
      );
      final url = presign['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        // Presigned URL is signed with X-Amz-SignedHeaders=host only; omit
        // Content-Type so the signature stays valid (and web CORS preflight is simpler).
        final put = await http.put(Uri.parse(url), body: bytes);
        ApiClient.notifyUnauthorizedFromStatusCode(put.statusCode);
        if (put.statusCode < 200 || put.statusCode >= 300) {
          throw Exception('Загрузка файла: ${put.statusCode}');
        }
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

  Future<void> updateProduct({
    required String productId,
    required String title,
    required String description,
    required int price,
    required bool isActive,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.patchJson(
      '/shop/products/$productId',
      accessToken: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'price': price,
        'isActive': isActive,
      },
    );
  }

  Future<void> deleteProduct(String productId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.deleteJson('/shop/products/$productId', accessToken: token);
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
    final data = await api.getJson(
      '/shop/purchases/pending',
      accessToken: token,
    );
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
