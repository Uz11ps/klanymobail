import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HERO (лендинг + auth) — меняй ТОЛЬКО константы ниже, все экраны сами.
// ═══════════════════════════════════════════════════════════════════════════
/// Ширина кадра в Figma (iPhone 17), логические pt — **390**.
const double kFigmaAuthHeroRefFrameWidth = 360;
/// Сторона квадрата hero на этом кадре (Figma Layout W = H) — **383**.

const double kFigmaAuthHeroRefSidePx = 360;

/// Скругление углов PNG.
const double kFigmaAuthHeroCornerRadius = 20;

/// Горизонтальный отступ вокруг hero (`Padding` на [Expanded]).
const double kFigmaAuthHeroInsetH = 10;

/// Минимальная сторона на очень узком экране.
const double kFigmaAuthHeroMinSidePx = 120;

/// Зазор между hero и формой под ним.
const double kFigmaAuthHeroBelowGap = 20;

/// Горизонтальные поля формы под hero (как [kFigmaAuthScreenPaddingH]).
const double kFigmaAuthHeroFormPaddingH = 16;

/// Отступ сверху секции hero под шапкой.
const double kFigmaAuthHeroSectionTop = 6;

/// Зазор от картинки до точек (лендинг и auth).
const double kFigmaHeroDotsGap = 8;

/// Диаметр активной точки.
const double kFigmaHeroDotsDiameter = 7;

/// Высота блока точек под hero.
const double kFigmaHeroDotsBlockHeight =
    kFigmaHeroDotsGap + kFigmaHeroDotsDiameter;

/// Сторона по **ширине слота** (как в Figma): refSide × (maxWidth / refFrame).
double figmaAuthHeroWidthSide(double maxWidth) {
  if (maxWidth < 8) return 0;
  final nominal =
      kFigmaAuthHeroRefSidePx * (maxWidth / kFigmaAuthHeroRefFrameWidth);
  var side = math.min(nominal, maxWidth);
  side = math.max(kFigmaAuthHeroMinSidePx, side);
  return side < 8 ? 0 : side;
}

/// Вписать квадрат в слот с ограниченной высотой (карусель в [Expanded]).
double figmaAuthHeroSlotSide({
  required double maxWidth,
  double? maxHeight,
  double reservedBelow = 0,
}) {
  var side = figmaAuthHeroWidthSide(maxWidth);
  if (side < 8) return 0;
  if (maxHeight != null && maxHeight.isFinite && maxHeight > 0) {
    final cap = math.max(0.0, maxHeight - reservedBelow);
    if (cap < side) {
      side = math.max(kFigmaAuthHeroMinSidePx, math.min(side, cap));
    }
  }
  return side < 8 ? 0 : side;
}

// ─── Общая вёрстка auth-экранов ───────────────────────────────────────────

/// Hero **не** в [Expanded] — размер только по ширине ([figmaAuthHeroWidthSide]).
class FigmaAuthHeroSection extends StatelessWidget {
  const FigmaAuthHeroSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: kFigmaAuthHeroSectionTop,
        left: kFigmaAuthHeroInsetH,
        right: kFigmaAuthHeroInsetH,
      ),
      child: child,
    );
  }
}

/// Форма под hero: [Expanded] + скролл, общие поля.
class FigmaAuthFormSection extends StatelessWidget {
  const FigmaAuthFormSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: kFigmaAuthHeroFormPaddingH,
        ),
        child: child,
      ),
    );
  }
}

/// Тело экрана: hero сверху (фикс. по ширине) + форма снизу.
class FigmaAuthPageBody extends StatelessWidget {
  const FigmaAuthPageBody({
    super.key,
    required this.hero,
    required this.form,
    this.bottomPadding = 12,
  });

  final Widget hero;
  final Widget form;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FigmaAuthHeroSection(child: hero),
          const SizedBox(height: kFigmaAuthHeroBelowGap),
          FigmaAuthFormSection(child: form),
        ],
      ),
    );
  }
}

// ─── Виджеты (лендинг + глава клана + участник) ───────────────────────────

const Color _kHeroDotColor = Color(0xFF000000);

/// Точки под hero / каруселью.
class FigmaAuthCarouselDots extends StatelessWidget {
  const FigmaAuthCarouselDots({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 7 : 5,
          height: active ? 7 : 5,
          decoration: BoxDecoration(
            color: active
                ? _kHeroDotColor
                : _kHeroDotColor.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// Одна картинка hero (скругление и размер — из констант выше).
class FigmaAuthHeroImage extends StatelessWidget {
  const FigmaAuthHeroImage({
    super.key,
    required this.asset,
    required this.side,
    this.fallbackColor = Colors.transparent,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String asset;
  final double side;
  final Color fallbackColor;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kFigmaAuthHeroCornerRadius),
      child: Image.asset(
        asset,
        width: side,
        height: side,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: fallbackColor,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 42,
            color: Color(0x665B6B85),
          ),
        ),
      ),
    );
  }
}

/// Один hero (auth: ребёнок / родитель).
class FigmaAuthHero extends StatelessWidget {
  const FigmaAuthHero({
    super.key,
    required this.asset,
    this.fallbackColor = Colors.transparent,
    this.showDots = false,
    this.dotCount = 3,
    this.activeDotIndex = 0,
    this.centerInSlot = false,
    this.constrainToSlotHeight = false,
  });

  final String asset;
  final Color fallbackColor;
  final bool showDots;
  final int dotCount;
  final int activeDotIndex;
  final bool centerInSlot;

  /// `true` — ужать квадрат по высоте [Expanded] (лендинг-карусель).
  final bool constrainToSlotHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite &&
                constraints.maxHeight > 0
            ? constraints.maxHeight
            : null;
        if (maxW < 8) {
          return const SizedBox.shrink();
        }

        final reserved = showDots ? kFigmaHeroDotsBlockHeight : 0.0;
        final side = constrainToSlotHeight
            ? figmaAuthHeroSlotSide(
                maxWidth: maxW,
                maxHeight: maxH,
                reservedBelow: reserved,
              )
            : figmaAuthHeroWidthSide(maxW);
        if (side < 8) {
          return const SizedBox.shrink();
        }

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FigmaAuthHeroImage(
                asset: asset,
                side: side,
                fallbackColor: fallbackColor,
                alignment: Alignment.bottomCenter,
              ),
            ),
            if (showDots) ...[
              SizedBox(height: kFigmaHeroDotsGap),
              FigmaAuthCarouselDots(
                count: dotCount,
                activeIndex: activeDotIndex,
              ),
            ],
          ],
        );

        if (constrainToSlotHeight &&
            maxH != null &&
            maxH > side + reserved + 8) {
          return centerInSlot
              ? Center(child: column)
              : Align(alignment: Alignment.topCenter, child: column);
        }
        return Align(alignment: Alignment.topCenter, child: column);
      },
    );
  }
}

/// Карусель hero (лендинг).
class FigmaAuthHeroCarousel extends StatefulWidget {
  const FigmaAuthHeroCarousel({
    super.key,
    required this.assets,
    this.fallbackColor = Colors.transparent,
    this.autoAdvanceSeconds = 5,
    this.initialIndex = 0,
    this.constrainToSlotHeight = false,
  });

  final List<String> assets;
  final Color fallbackColor;
  final int autoAdvanceSeconds;
  final int initialIndex;

  /// `true` только если карусель внутри [Expanded] с жёсткой высотой.
  final bool constrainToSlotHeight;

  @override
  State<FigmaAuthHeroCarousel> createState() => _FigmaAuthHeroCarouselState();
}

class _FigmaAuthHeroCarouselState extends State<FigmaAuthHeroCarousel> {
  late final PageController _pageController;
  late int _index;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.assets.length - 1);
    _pageController = PageController(initialPage: _index);
    if (widget.autoAdvanceSeconds > 0 && widget.assets.length > 1) {
      _autoTimer = Timer.periodic(
        Duration(seconds: widget.autoAdvanceSeconds),
        (_) {
          if (!mounted || !_pageController.hasClients) return;
          final next = (_index + 1) % widget.assets.length;
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite &&
                constraints.maxHeight > 0
            ? constraints.maxHeight
            : null;
        if (maxW < 8) {
          return const SizedBox.shrink();
        }

        final side = widget.constrainToSlotHeight
            ? figmaAuthHeroSlotSide(
                maxWidth: maxW,
                maxHeight: maxH,
                reservedBelow: kFigmaHeroDotsBlockHeight,
              )
            : figmaAuthHeroWidthSide(maxW);
        if (side < 8) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: side,
              child: PageView.builder(
                controller: _pageController,
                padEnds: true,
                clipBehavior: Clip.none,
                itemCount: widget.assets.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Center(
                  child: FigmaAuthHeroImage(
                    asset: widget.assets[i],
                    side: side,
                    fallbackColor: widget.fallbackColor,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SizedBox(height: kFigmaHeroDotsGap),
            FigmaAuthCarouselDots(
              count: widget.assets.length,
              activeIndex: _index,
            ),
          ],
        );
      },
    );
  }
}

@Deprecated('Use FigmaAuthHero')
typedef FigmaAuthHeroCarouselSlot = FigmaAuthHero;
