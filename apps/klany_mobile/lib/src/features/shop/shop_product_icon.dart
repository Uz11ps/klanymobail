import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'shop_repository.dart';

/// Один вариант иконки товара: реальный SVG из Figma + старый эмодзи для совместимости.
class ShopProductIconOption {
  const ShopProductIconOption({
    required this.id,
    required this.legacyEmoji,
    required this.asset,
  });

  final String id;
  final String legacyEmoji;
  final String asset;
}

/// Набор иконок витрины (порядок как в макете «выбрать иконку»).
const kShopProductIconOptions = <ShopProductIconOption>[
  ShopProductIconOption(
    id: 'gamepad',
    legacyEmoji: '🎮',
    asset: 'assets/figma/product_gamepad.svg',
  ),
  ShopProductIconOption(
    id: 'bear',
    legacyEmoji: '🐻',
    asset: 'assets/figma/product_bear.svg',
  ),
  ShopProductIconOption(
    id: 'books',
    legacyEmoji: '📚',
    asset: 'assets/figma/product_books.svg',
  ),
  ShopProductIconOption(
    id: 'headphones',
    legacyEmoji: '🎧',
    asset: 'assets/figma/product_headphones.svg',
  ),
  ShopProductIconOption(
    id: 'football',
    legacyEmoji: '🏈',
    asset: 'assets/figma/product_football.svg',
  ),
  ShopProductIconOption(
    id: 'gift',
    legacyEmoji: '🎁',
    asset: 'assets/figma/product_gift.svg',
  ),
  ShopProductIconOption(
    id: 'popcorn',
    legacyEmoji: '🍿',
    asset: 'assets/figma/product_popcorn.svg',
  ),
  ShopProductIconOption(
    id: 'bicycle',
    legacyEmoji: '🚲',
    asset: 'assets/figma/product_bicycle.svg',
  ),
];

final _leadingIconTag = RegExp(r'^\[icon:([a-zA-Z0-9_-]+)\]\s*');

ShopProductIconOption? shopProductIconOptionById(String id) {
  for (final o in kShopProductIconOptions) {
    if (o.id == id) return o;
  }
  return null;
}

/// Явный маркер `[icon:id]` в начале описания или устаревший эмодзи в начале строки.
String? shopProductIconIdFromDescription(String? description) {
  if (description == null || description.isEmpty) return null;
  final s = description.trimLeft();
  final m = _leadingIconTag.firstMatch(s);
  if (m != null) return m.group(1);
  for (final o in kShopProductIconOptions) {
    if (s.startsWith(o.legacyEmoji)) return o.id;
  }
  return null;
}

/// Текст описания без служебного префикса иконки (для полей ввода).
String shopProductDescriptionWithoutIconMarker(String? description) {
  if (description == null) return '';
  var s = description.trimLeft();
  final m = _leadingIconTag.firstMatch(s);
  if (m != null) {
    return s.substring(m.end).trimLeft();
  }
  for (final o in kShopProductIconOptions) {
    if (s.startsWith(o.legacyEmoji)) {
      return s.substring(o.legacyEmoji.length).trimLeft();
    }
  }
  return description.trim();
}

/// Как сохраняем описание: выбранная родителем иконка кодируется маркером, без «угадывания» по словам.
String composeShopProductDescription({
  String? iconId,
  required String userDescription,
}) {
  final text = userDescription.trim();
  if (iconId == null || iconId.isEmpty) {
    return text;
  }
  final prefix = '[icon:$iconId]';
  if (text.isEmpty) return prefix;
  return '$prefix $text';
}

/// Иконка для карточки: только маркер/эмодзи в данных, без матчинга по ключевым словам в названии.
ShopProductIconOption shopProductResolvedIcon(ShopProductItem p) {
  final desc = p.description ?? '';
  final fromStart = shopProductIconIdFromDescription(desc);
  if (fromStart != null) {
    final opt = shopProductIconOptionById(fromStart);
    if (opt != null) return opt;
  }
  final haystack = '${p.title} $desc';
  for (final o in kShopProductIconOptions) {
    if (haystack.contains(o.legacyEmoji)) return o;
  }
  return kShopProductIconOptions.firstWhere((o) => o.id == 'gift');
}

/// Отрисовка SVG-иконки товара (ассеты из Figma).
class ShopProductIconSvg extends StatelessWidget {
  const ShopProductIconSvg({
    super.key,
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
