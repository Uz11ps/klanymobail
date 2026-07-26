import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/klany_figma_style.dart';

/// Figma [node 1:141](https://www.figma.com/design/YsSajeAgXSHK88ETbeV4N9/Untitled?node-id=1-141).
enum ParentMainTab { home, exchange, shop, settings }

abstract final class ParentMainBottomBarLayout {
  static const double pillHeight = 92;
  static const double pillRadius = 22;
  static const double iconCircle = 57;
  static const double iconSize = 29;
  static const double labelSize = 16;
  static const double horizontalMargin = 3;
  static const Color activeBlue = Color(0xFF4563B1);
  static const Color borderBlue = Color(0xFF22459E);
  static const Color inactiveGray = Color(0xFFACACAC);

  static double scaledPillHeight(BuildContext context) =>
      context.klanySize(pillHeight);
}

class ParentMainBottomBar extends StatelessWidget {
  const ParentMainBottomBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final ParentMainTab current;
  final ValueChanged<ParentMainTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scale = context.klanyScale;
    final pillHeight = context.klanySize(ParentMainBottomBarLayout.pillHeight);
    final pillRadius = context.klanySize(ParentMainBottomBarLayout.pillRadius);
    final hMargin = context.klanySize(ParentMainBottomBarLayout.horizontalMargin);
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
                color: ParentMainBottomBarLayout.borderBlue,
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
                  child: _NavItem(
                    label: 'Дом',
                    asset: 'assets/figma/parent_nav_home.svg',
                    selected: current == ParentMainTab.home,
                    onTap: () => onSelected(ParentMainTab.home),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Биржа',
                    asset: 'assets/figma/parent_nav_exchange.svg',
                    selected: current == ParentMainTab.exchange,
                    onTap: () => onSelected(ParentMainTab.exchange),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Магазин',
                    asset: 'assets/figma/parent_nav_shop.svg',
                    selected: current == ParentMainTab.shop,
                    onTap: () => onSelected(ParentMainTab.shop),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Настройки',
                    asset: 'assets/figma/nav_tune.svg',
                    selected: current == ParentMainTab.settings,
                    iconSize: ParentMainBottomBarLayout.iconSize,
                    onTap: () => onSelected(ParentMainTab.settings),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
    this.iconSize = ParentMainBottomBarLayout.iconSize,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final circle = context.klanySize(ParentMainBottomBarLayout.iconCircle);
    final icon = context.klanySize(iconSize);
    final labelSize = context.klanySize(ParentMainBottomBarLayout.labelSize);
    final circleColor =
        selected ? ParentMainBottomBarLayout.activeBlue : Colors.white;
    final iconColor =
        selected ? Colors.white : ParentMainBottomBarLayout.inactiveGray;
    final labelColor = selected
        ? ParentMainBottomBarLayout.activeBlue
        : ParentMainBottomBarLayout.inactiveGray;
    final labelWeight = selected ? FontWeight.w700 : FontWeight.w500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
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
