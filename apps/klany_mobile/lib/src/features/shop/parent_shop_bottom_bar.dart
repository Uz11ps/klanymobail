import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/klany_figma_style.dart';

/// Figma [node 1:904](https://www.figma.com/design/YsSajeAgXSHK88ETbeV4N9/Untitled?node-id=1-904).
enum ParentShopTab { catalog, addProduct, purchaseRequests, economy }

abstract final class ParentShopBottomBarLayout {
  static const double pillHeight = 92;
  static const double pillRadius = 22;
  static const Color borderBlue = Color(0xFF22459E);
  static const Color activeBlue = Color(0xFF4563B1);
  static const Color inactiveGray = Color(0xFFACACAC);
  static const double activeCircle = 57;
  static const double idleCircle = 52;
  static const double iconSize = 26;
  static const double labelSize = 14;
  static const double horizontalMargin = 3;

  static double scaledPillHeight(BuildContext context) =>
      context.klanySize(pillHeight);
}

class ParentShopBottomBar extends StatelessWidget {
  const ParentShopBottomBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final ParentShopTab current;
  final ValueChanged<ParentShopTab> onSelected;

  static ParentShopTab tabFromIndex(int index) => switch (index) {
        1 => ParentShopTab.addProduct,
        2 => ParentShopTab.purchaseRequests,
        3 => ParentShopTab.economy,
        _ => ParentShopTab.catalog,
      };

  static int indexFromTab(ParentShopTab tab) => switch (tab) {
        ParentShopTab.addProduct => 1,
        ParentShopTab.purchaseRequests => 2,
        ParentShopTab.economy => 3,
        ParentShopTab.catalog => 0,
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scale = context.klanyScale;
    final pillHeight = context.klanySize(ParentShopBottomBarLayout.pillHeight);
    final pillRadius = context.klanySize(ParentShopBottomBarLayout.pillRadius);
    final hMargin = context.klanySize(ParentShopBottomBarLayout.horizontalMargin);
    final bottomPad = context.klanySize(16);

    return SizedBox(
      height: pillHeight + bottomPad + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hMargin,
          0,
          hMargin,
          bottomPad + bottomInset,
        ),
        child: SizedBox(
          width: double.infinity,
          height: pillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(pillRadius),
              border: Border.all(
                color: ParentShopBottomBarLayout.borderBlue,
                width: 1.5 * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ShopNavItem(
                    label: 'Товары',
                    asset: 'assets/figma/shop_nav_list.svg',
                    selected: current == ParentShopTab.catalog,
                    onTap: () => onSelected(ParentShopTab.catalog),
                  ),
                ),
                Expanded(
                  child: _ShopNavItem(
                    label: 'Добавить',
                    asset: 'assets/figma/shop_nav_plus.svg',
                    selected: current == ParentShopTab.addProduct,
                    onTap: () => onSelected(ParentShopTab.addProduct),
                  ),
                ),
                Expanded(
                  child: _ShopNavItem(
                    label: 'Запросы',
                    asset: 'assets/figma/shop_nav_bag.svg',
                    selected: current == ParentShopTab.purchaseRequests,
                    onTap: () => onSelected(ParentShopTab.purchaseRequests),
                  ),
                ),
                Expanded(
                  child: _ShopNavItem(
                    label: 'Экономика',
                    asset: 'assets/figma/parent_nav_exchange.svg',
                    selected: current == ParentShopTab.economy,
                    onTap: () => onSelected(ParentShopTab.economy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopNavItem extends StatelessWidget {
  const _ShopNavItem({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circleBase = selected
        ? ParentShopBottomBarLayout.activeCircle
        : ParentShopBottomBarLayout.idleCircle;
    final circle = context.klanySize(circleBase);
    final icon = context.klanySize(ParentShopBottomBarLayout.iconSize);
    final labelSize = context.klanySize(ParentShopBottomBarLayout.labelSize);
    final circleColor =
        selected ? ParentShopBottomBarLayout.activeBlue : Colors.transparent;
    final iconColor =
        selected ? Colors.white : ParentShopBottomBarLayout.inactiveGray;
    final labelColor = selected
        ? ParentShopBottomBarLayout.activeBlue
        : ParentShopBottomBarLayout.inactiveGray;
    final labelWeight = selected ? FontWeight.w700 : FontWeight.w500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: ParentShopBottomBarLayout.activeBlue
                              .withValues(alpha: 0.35),
                          blurRadius: context.klanySize(12),
                          offset: Offset(0, context.klanySize(4)),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                asset,
                width: icon,
                height: icon,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: context.klanySize(4)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: labelSize,
                  fontWeight: labelWeight,
                  color: labelColor,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
