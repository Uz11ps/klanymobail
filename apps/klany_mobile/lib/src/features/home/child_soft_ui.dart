import 'package:flutter/material.dart';

// Brand palette reverse-engineered from the shipped APK snapshot.
const Color kChildBrandBlue = Color(0xFF2E63D8);
const Color kChildBrandBlueDark = Color(0xFF1A4BBF);
const Color kChildSurfaceSoft = Color(0xFFEFF4FA);
const Color kChildSurfaceWhite = Color(0xFFFFFFFF);
const Color kChildOutline = Color(0xFFD7E1F2);
const Color kChildInk = Color(0xFF0B1A33);
const Color kChildInkMuted = Color(0xFF5B6B85);
const Color kChildAccentOrange = Color(0xFFF5A524);
const Color kChildAccentGreen = Color(0xFF18B26B);

class ChildSoftCard extends StatelessWidget {
  const ChildSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? kChildSurfaceWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? kChildOutline,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14123A7A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class ChildSectionScaffold extends StatelessWidget {
  const ChildSectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kChildBrandBlue,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kChildInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChildBottomNavPill extends StatelessWidget {
  const _ChildBottomNavPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? kChildBrandBlue : kChildSurfaceWhite;
    final fg = selected ? Colors.white : kChildBrandBlue;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? kChildBrandBlue : kChildBrandBlue,
                  width: 1.4,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fg, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChildBottomClanBar extends StatelessWidget {
  const ChildBottomClanBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.items = const [
      ChildBottomNavItem(icon: Icons.home_filled, label: 'Дом'),
      ChildBottomNavItem(icon: Icons.task_alt, label: 'Биржа'),
      ChildBottomNavItem(icon: Icons.storefront, label: 'Магазин'),
    ],
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<ChildBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              _ChildBottomNavPill(
                icon: items[i].icon,
                label: items[i].label,
                selected: currentIndex == i,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class ChildBottomNavItem {
  const ChildBottomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
