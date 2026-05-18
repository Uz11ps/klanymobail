import 'dart:math' as math;

// ═══════════════════════════════════════════════════════════════════════════
// AUTH HERO — меняй ТОЛЬКО константы ниже, все экраны подхватят сами.
// ═══════════════════════════════════════════════════════════════════════════

/// Ширина кадра в Figma (iPhone 17), логические pt — **390**.
const double kFigmaAuthHeroRefFrameWidth = 390;

/// Сторона квадрата hero на этом кадре (Figma Layout W = H) — **383**.
const double kFigmaAuthHeroRefSidePx = 383;

/// Скругление углов PNG.
const double kFigmaAuthHeroCornerRadius = 20;

/// Горизонтальный отступ вокруг hero (`Padding` на [Expanded]).
const double kFigmaAuthHeroInsetH = 3;

/// Минимальная сторона на очень узком экране.
const double kFigmaAuthHeroMinSidePx = 120;

/// Зазор между hero и формой под ним.
const double kFigmaAuthHeroBelowGap = 20;

/// Адаптивная сторона: **refSide × (короткая сторона экрана / refFrame)**,
/// затем вписывание в слот [maxWidth] × [maxHeight].
double figmaAuthHeroSide({
  required double maxWidth,
  double? maxHeight,
  required double referenceShortestSide,
}) {
  if (maxWidth < 8) return 0;
  final ref = math.max(1.0, referenceShortestSide);
  final nominal =
      kFigmaAuthHeroRefSidePx * (ref / kFigmaAuthHeroRefFrameWidth);
  final capH =
      (maxHeight != null && maxHeight.isFinite && maxHeight > 0)
          ? maxHeight
          : double.infinity;
  var side = math.min(nominal, maxWidth);
  if (capH.isFinite) {
    side = math.min(side, capH);
  }
  side = math.max(kFigmaAuthHeroMinSidePx, side);
  if (side > maxWidth) side = maxWidth;
  if (capH.isFinite && side > capH) side = capH;
  return side < 8 ? 0 : side;
}
