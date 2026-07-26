import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return SizedBox(
      height: ParentMainBottomBarLayout.pillHeight + 16 + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ParentMainBottomBarLayout.horizontalMargin,
          0,
          ParentMainBottomBarLayout.horizontalMargin,
          16 + bottomInset,
        ),
        child: SizedBox(
          width: double.infinity,
          height: ParentMainBottomBarLayout.pillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                ParentMainBottomBarLayout.pillRadius,
              ),
              border: Border.all(
                color: ParentMainBottomBarLayout.borderBlue,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
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
                    iconSize: 26,
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
                width: ParentMainBottomBarLayout.iconCircle,
                height: ParentMainBottomBarLayout.iconCircle,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  asset,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: ParentMainBottomBarLayout.labelSize,
                  fontWeight: labelWeight,
                  color: labelColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
