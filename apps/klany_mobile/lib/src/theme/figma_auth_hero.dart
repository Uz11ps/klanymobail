import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════

// HERO — квадрат в слоте, макс. [kFigmaAuthHeroMaxSide].

// Лендинг: [Expanded] между заголовком и кнопками.

// Auth: hero забирает всё место над формой (форма не [Expanded]).

// ═══════════════════════════════════════════════════════════════════════════

/// Максимальная сторона квадрата на любом экране.

const double kFigmaAuthHeroMaxSide = 1024;

/// Минимум на очень маленьком экране.

const double kFigmaAuthHeroMinSide = 244;

/// Скругление углов PNG.

const double kFigmaAuthHeroCornerRadius = 20;

/// Горизонтальный отступ вокруг hero.

const double kFigmaAuthHeroInsetH = 10;

/// Зазор между hero и формой под ним.

const double kFigmaAuthHeroBelowGap = 20;

/// Горизонтальные поля формы под hero.

const double kFigmaAuthHeroFormPaddingH = 16;

/// Отступ сверху секции hero.

const double kFigmaAuthHeroSectionTop = 8;

/// Зазор от картинки до точек.

const double kFigmaHeroDotsGap = 8;

/// Диаметр активной точки.

const double kFigmaHeroDotsDiameter = 7;

/// Высота блока точек под hero.

const double kFigmaHeroDotsBlockHeight =
    kFigmaHeroDotsGap + kFigmaHeroDotsDiameter;

/// Алиасы для старых имён.

const double kFigmaAuthHeroMaxWidth = kFigmaAuthHeroMaxSide;

const double kFigmaAuthHeroMaxHeight = kFigmaAuthHeroMaxSide;

/// Сторона квадрата: вписать в слот, не больше [kFigmaAuthHeroMaxSide].

double figmaAuthHeroSquareSide({
  required double slotWidth,

  double? slotHeight,

  double reservedBelow = 0,
}) {
  if (slotWidth < 8) return 0;

  var side = math.min(slotWidth, kFigmaAuthHeroMaxSide);

  if (slotHeight != null && slotHeight.isFinite && slotHeight > 0) {
    final cap = slotHeight - reservedBelow;

    if (cap <= 0) return 0;

    side = math.min(side, cap);
  }

  // Не раздуваем квадрат до минимума, если слот уже ниже — иначе при клавиатуре
  // получается переполнение и налезание на форму.
  if (side >= kFigmaAuthHeroMinSide) {
    side = math.max(kFigmaAuthHeroMinSide, side);
  }

  return side < 8 ? 0 : side;
}

/// Порог для [MediaQuery.viewInsets.bottom]: считаем клавиатуру открытой.
const double kFigmaAuthHeroKeyboardInsetThreshold = 12;

bool figmaAuthHeroKeyboardLikelyOpen(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom >
    kFigmaAuthHeroKeyboardInsetThreshold;

// ─── Общая вёрстка auth-экранов ───────────────────────────────────────────

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

/// Форма под hero: только своя высота, как CTA-блок на лендинге.

class FigmaAuthFormSection extends StatelessWidget {
  const FigmaAuthFormSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kFigmaAuthHeroFormPaddingH,
      ),
      child: child,
    );
  }
}

/// Hero над формой: [Flexible] на всю высоту; при открытой клавиатуре скрывается.

class FigmaAuthPageBody extends StatelessWidget {
  const FigmaAuthPageBody({
    super.key,

    required this.hero,

    required this.form,

    this.bottomPadding = 0,
  });

  final Widget hero;

  final Widget form;

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = figmaAuthHeroKeyboardLikelyOpen(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          // При открытой клавиатуре hero убираем из дерева — форма занимает место,
          // без изменения поведения лендинга (он не использует этот виджет).
          Flexible(
            flex: keyboardOpen ? 0 : 1,

            fit: keyboardOpen ? FlexFit.loose : FlexFit.tight,

            child: keyboardOpen
                ? const SizedBox.shrink()
                : FigmaAuthHeroSection(child: hero),
          ),

          if (!keyboardOpen) const SizedBox(height: kFigmaAuthHeroBelowGap),

          FigmaAuthFormSection(child: form),
        ],
      ),
    );
  }
}

// ─── Виджеты (лендинг + глава клана + участник) ───────────────────────────

const Color _kHeroDotColor = Color(0xFF000000);

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

class FigmaAuthHeroImage extends StatelessWidget {
  const FigmaAuthHeroImage({
    super.key,

    required this.asset,

    required this.side,

    this.fit = BoxFit.contain,

    this.alignment = Alignment.center,
  });

  final String asset;

  final double side;

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

        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: side,
          height: side,
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

class FigmaAuthHero extends StatelessWidget {
  const FigmaAuthHero({
    super.key,

    required this.asset,

    this.showDots = false,

    this.dotCount = 3,

    this.activeDotIndex = 0,

    this.imageFit = BoxFit.contain,
  });

  final String asset;

  final bool showDots;

  final int dotCount;

  final int activeDotIndex;

  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;

        final maxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : null;

        if (maxW < 8) {
          return const SizedBox.shrink();
        }

        final reserved = showDots ? kFigmaHeroDotsBlockHeight : 0.0;

        final side = figmaAuthHeroSquareSide(
          slotWidth: maxW,

          slotHeight: maxH,

          reservedBelow: reserved,
        );

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
                fit: imageFit,
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

        if (maxH != null) {
          return Center(child: column);
        }

        return Align(alignment: Alignment.topCenter, child: column);
      },
    );
  }
}

class FigmaAuthHeroCarousel extends StatefulWidget {
  const FigmaAuthHeroCarousel({
    super.key,

    required this.assets,

    this.autoAdvanceSeconds = 5,

    this.initialIndex = 0,

    this.imageFit = BoxFit.contain,
  });

  final List<String> assets;

  final int autoAdvanceSeconds;

  final int initialIndex;

  final BoxFit imageFit;

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

        final maxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : null;

        if (maxW < 8) {
          return const SizedBox.shrink();
        }

        final side = figmaAuthHeroSquareSide(
          slotWidth: maxW,

          slotHeight: maxH,

          reservedBelow: kFigmaHeroDotsBlockHeight,
        );

        if (side < 8) {
          return const SizedBox.shrink();
        }

        final column = Column(
          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(kFigmaAuthHeroCornerRadius),
              child: SizedBox(
                height: side,
                child: PageView.builder(
                  controller: _pageController,
                  padEnds: true,
                  itemCount: widget.assets.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Center(
                    child: FigmaAuthHeroImage(
                      asset: widget.assets[i],
                      side: side,
                      fit: widget.imageFit,
                    ),
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

        if (maxH != null) {
          return Center(child: column);
        }

        return Align(alignment: Alignment.topCenter, child: column);
      },
    );
  }
}

@Deprecated('Use FigmaAuthHero')
typedef FigmaAuthHeroCarouselSlot = FigmaAuthHero;
