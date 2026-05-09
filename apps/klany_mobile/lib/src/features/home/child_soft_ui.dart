import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clan_capital_ui.dart';

// Brand palette — canonical source is clan_capital_ui.dart for the two primaries.
// Re-exported here so callers that already import child_soft_ui.dart keep working.
export 'clan_capital_ui.dart' show kChildBrandBlue, kChildInk, ClanCapitalUi;

const Color kChildBrandBlueDark = Color(0xFF1A4BBF);
const Color kChildSurfaceSoft = Color(0xFFEFF4FA);
const Color kChildSurfaceWhite = Color(0xFFFFFFFF);
const Color kChildOutline = Color(0xFFD7E1F2);
const Color kChildInkMuted = Color(0xFF5B6B85);
const Color kChildAccentOrange = Color(0xFFF5A524);
const Color kChildAccentGreen = Color(0xFF18B26B);

// New design palette (Figma)
const Color kBrandMint = Color(0xFFC5F2C0);
const Color kBrandMintDark = Color(0xFF7BC976);
const Color kBrandSky = Color(0xFFD8E9F8);
const Color kBrandSkyDark = Color(0xFF7AA5D6);
const Color kBrandLavender = Color(0xFFE6DDF5);
const Color kBrandLavenderDark = Color(0xFF7B6FD0);
const Color kBrandSunny = Color(0xFFFFE9A8);
const Color kBrandPeach = Color(0xFFFFD1B8);
const Color kBrandRose = Color(0xFFF8D2D8);
const Color kBgCloud = Color(0xFFEFF6FB);

/// Тень-«объём» под кнопками (как в Figma) — жёсткая нижняя полоса.
Color _darkenColor(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
      .toColor();
}

List<BoxShadow> kSoftButtonShadow(Color tint) => [
      BoxShadow(
        color: _darkenColor(tint, 0.18),
        offset: const Offset(0, 5),
        blurRadius: 0,
        spreadRadius: 0,
      ),
    ];

/// Кнопка с цветной тенью снизу (универсальный wrapper).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.onTap,
    required this.label,
    this.bg = kBrandMint,
    this.fg = const Color(0xFF1F4F1B),
    this.height = 54,
    this.fontSize = 16,
    this.icon,
  });

  final VoidCallback? onTap;
  final String label;
  final Color bg;
  final Color fg;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: kSoftButtonShadow(bg),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(height / 2),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: fg, size: fontSize + 4),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: fg,
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

/// Иконка стопки монет (3 эллипса с боковыми стенками).
class CoinStackIcon extends StatelessWidget {
  const CoinStackIcon({super.key, this.size = 24, this.color = kChildBrandBlue});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinStackPainter(color)),
    );
  }
}

class _CoinStackPainter extends CustomPainter {
  _CoinStackPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final coinW = w * 0.95;
    final coinH = h * 0.32;
    final cx = w / 2;
    for (int i = 0; i < 3; i++) {
      final cy = h - coinH / 2 - i * (coinH * 0.85);
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: coinW,
        height: coinH,
      );
      canvas.drawOval(rect, stroke);
      final leftX = cx - coinW / 2;
      final rightX = cx + coinW / 2;
      canvas.drawLine(
        Offset(leftX, cy),
        Offset(leftX, cy + coinH * 0.45),
        stroke,
      );
      canvas.drawLine(
        Offset(rightX, cy),
        Offset(rightX, cy + coinH * 0.45),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinStackPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Облачный фон-картинка для основных экранов приложения.
class CloudBackground extends StatelessWidget {
  const CloudBackground({super.key, required this.child, this.opacity = 0.55});
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBgCloud,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                'assets/figma/cloud_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class ChildSoftCard extends StatelessWidget {
  const ChildSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor; // kept for API compat, not used (neuCard has no border)
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ClanCapitalUi.neuCard(
        color: color ?? kChildSurfaceSoft,
        radius: radius,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
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
              Expanded(child: ClanCapitalUi.logoHeader(title)),
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
      ChildBottomNavItem(icon: Icons.home_outlined, label: 'Дом'),
      ChildBottomNavItem(icon: Icons.assignment_outlined, label: 'Биржа'),
      ChildBottomNavItem(icon: Icons.shopping_bag_outlined, label: 'Магазин'),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < items.length; i++)
                _ChildNavLabeledBtn(
                  icon: items[i].icon,
                  label: items[i].label,
                  selected: currentIndex == i,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildNavLabeledBtn extends StatelessWidget {
  const _ChildNavLabeledBtn({
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
    final fg = selected ? Colors.white : kChildInkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kChildBrandBlue : Colors.transparent,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(
                          color: kChildOutline,
                          width: 1.4,
                        ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? kChildInk : kChildInkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildNavRoundBtn extends StatelessWidget {
  const _ChildNavRoundBtn({
    required this.icon,
    required this.selected,
    required this.big,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (big) {
      return Material(
        color: kChildBrandBlue,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: kChildBrandBlue.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ),
      );
    }
    return Material(
      color: selected
          ? kChildBrandBlue.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: 24,
            color: selected ? kChildBrandBlue : kChildInkMuted,
          ),
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
    fillColor: Colors.white,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
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
          elevation: 4,
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
