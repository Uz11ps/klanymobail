import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'shop_product_icon.dart';

/// Ключ файла в дисковом кэше [CachedNetworkImage]: совпадает с объектом в bucket,
/// пока родитель не загрузит новое фото (новый `imageKey`).
String shopProductImageCacheKey(String productId, String? imageStorageKey) {
  final k = (imageStorageKey ?? '').trim();
  if (k.isNotEmpty) return 'shop-products::$k';
  return 'shop-products::id-$productId';
}

/// Превью фото товара с сохранением на устройстве; presigned URL может меняться — кэш по [cacheKey].
class ShopProductCachedImage extends StatelessWidget {
  const ShopProductCachedImage({
    super.key,
    required this.imageUrl,
    required this.productId,
    required this.imageStorageKey,
    required this.width,
    required this.height,
    required this.fit,
    required this.errorIconAsset,
    this.iconSize,
  });

  final String imageUrl;
  final String productId;
  final String? imageStorageKey;
  final double width;
  final double height;
  final BoxFit fit;
  final String errorIconAsset;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final mw = (width * dpr).round().clamp(1, 4096);
    final mh = (height * dpr).round().clamp(1, 4096);
    final fallbackSize = iconSize ?? width;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: shopProductImageCacheKey(productId, imageStorageKey),
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: mw,
      memCacheHeight: mh,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.04),
        child: SizedBox(width: width, height: height),
      ),
      errorWidget: (context, url, error) => ShopProductIconSvg(
        asset: errorIconAsset,
        size: fallbackSize,
      ),
    );
  }
}
