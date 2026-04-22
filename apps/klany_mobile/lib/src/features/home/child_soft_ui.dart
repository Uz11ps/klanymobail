import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Brand palette reverse-engineered from the shipped APK snapshot.
const Color kChildBrandBlue = Color(0xFF2E63D8);
const Color kChildBrandBlueDark = Color(0xFF1A4BBF);
const Color kChildSurfaceSoft = Color(0xFFEFF4FA);
const Color kChildSurfaceWhite = Color(0xFFFFFFFF);
const Color kChildOutline = Color(0xFFD7E1F2);
const Color kChildInk = Color(0xFF1E2D52);
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

class ClanAuthScaffold extends StatelessWidget {
  const ClanAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
    this.showBrandHeader = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? leading;
  final bool showBrandHeader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kChildSurfaceSoft,
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ?leading,
                if (showBrandHeader)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'CLAN CAPITAL',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kChildBrandBlue,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kChildInk,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: kChildInkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ClanActionCard extends StatelessWidget {
  const ClanActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? kChildBrandBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ChildSoftCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kChildInkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class ClanPrimaryButton extends StatelessWidget {
  const ClanPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : (icon != null ? Icon(icon) : const SizedBox.shrink()),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kChildBrandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}

class ClanSecondaryButton extends StatelessWidget {
  const ClanSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kChildBrandBlue,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: kChildBrandBlue, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}

InputDecoration clanInputDecoration({
  required String label,
  IconData? icon,
  String? hint,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counterText,
    prefixIcon: icon != null ? Icon(icon, color: kChildBrandBlue) : null,
    filled: true,
    fillColor: kChildSurfaceWhite,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kChildOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kChildOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.6),
    ),
  );
}

class ClanSectionPage extends StatelessWidget {
  const ClanSectionPage({
    super.key,
    required this.title,
    required this.slivers,
    this.onRefresh,
    this.onRefreshAsync,
  });

  final String title;
  final List<Widget> slivers;
  final VoidCallback? onRefresh;
  final Future<void> Function()? onRefreshAsync;

  @override
  Widget build(BuildContext context) {
    final body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: kChildInk,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: kChildInk,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
          ],
        ),
        ...slivers,
      ],
    );

    return Container(
      color: kChildSurfaceSoft,
      child: onRefreshAsync != null
          ? RefreshIndicator(onRefresh: onRefreshAsync!, child: body)
          : body,
    );
  }
}

class ClanBackButton extends StatelessWidget {
  const ClanBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: kChildSurfaceWhite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: kChildOutline),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back,
              color: kChildBrandBlue,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
