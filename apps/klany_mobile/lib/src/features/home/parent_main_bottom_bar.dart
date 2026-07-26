import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma [node 1:141](https://www.figma.com/design/YsSajeAgXSHK88ETbeV4N9/Untitled?node-id=1-141).
enum ParentMainTab { home, exchange, shop, settings }

abstract final class ParentMainBottomBarLayout {
  static const double pillWidth = 386;
  static const double pillHeight = 92;
  static const double pillRadius = 45;
  static const double iconCircle = 57;
  static const double iconSize = 29;
  static const double labelSize = 16;
  static const Color activeBlue = Color(0xFF4563B1);
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
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ParentMainBottomBarLayout.pillWidth,
            ),
            child: SizedBox(
              height: ParentMainBottomBarLayout.pillHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    ParentMainBottomBarLayout.pillRadius,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      label: 'Дом',
                      asset: 'assets/figma/parent_nav_home.svg',
                      selected: current == ParentMainTab.home,
                      onTap: () => onSelected(ParentMainTab.home),
                    ),
                    _NavItem(
                      label: 'Биржа',
                      asset: 'assets/figma/parent_nav_exchange.svg',
                      selected: current == ParentMainTab.exchange,
                      onTap: () => onSelected(ParentMainTab.exchange),
                    ),
                    _NavItem(
                      label: 'Магазин',
                      asset: 'assets/figma/parent_nav_shop.svg',
                      selected: current == ParentMainTab.shop,
                      onTap: () => onSelected(ParentMainTab.shop),
                    ),
                    _NavItem(
                      label: 'Настройки',
                      asset: 'assets/figma/nav_tune.svg',
                      selected: current == ParentMainTab.settings,
                      iconSize: 26,
                      onTap: () => onSelected(ParentMainTab.settings),
                    ),
                  ],
                ),
              ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 82,
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
      ),
    );
  }
}
