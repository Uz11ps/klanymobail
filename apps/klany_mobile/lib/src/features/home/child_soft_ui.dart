import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/klany_figma_style.dart';
export '../../theme/klany_figma_style.dart';

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

/// Child dashboard + bottom bar ([Figma child home](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-137)).
const Color kFigmaChildScreenBlue = Color(0xFF4563B1);
const Color kFigmaChildNavPillBorder = Color(0xFF22459E);
const Color kFigmaChildNavLabelMuted = Color(0xFFACACAC);
const Color kFigmaChildStatMint = Color(0xFFD9F6C2);
const Color kFigmaChildStatLavender = Color(0xFFD8CBF7);
const Color kFigmaChildGoalCard = Color(0xFFF9E8A5);
const Color kFigmaChildGoalThumb = Color(0xFFEACC56);
const Color kFigmaChildBalancePill = Color(0xFFF2F7FF);
const double kFigmaChildBottomBarMaxWidth = 311;

/// Центральная колонка дашборда ребёнка и экрана задач ([Figma] 393 → колонка 353).
/// На больших экранах раньше упирались в 560 px — на вебе это выглядело узкой полосой.
double kFigmaChildDashboardContentWidth(double screenWidth) {
  const designCol = 353.0;
  if (screenWidth < 430) {
    return math.min(designCol, math.max(0.0, screenWidth - 40));
  }
  if (screenWidth < 700) return math.min(screenWidth - 56, 430);
  // Десктоп и Flutter web — без жёсткого max 920 px.
  final side = math.max(24.0, screenWidth * 0.02);
  return math.max(designCol, screenWidth - 2 * side);
}

/// Горизонтальные отступы так, чтобы колонка [contentWidth] была по центру (без `clamp(..., 400)`).
double kFigmaChildDashboardHorizontalPadding(
  double screenWidth,
  double contentWidth,
) => math.max(16.0, (screenWidth - contentWidth) / 2);

/// Растровый экспорт той же графики, что и в [`profile_coin_stack.svg`].
/// На вебе `flutter_svg` не раскладывает паттерн с встроенным PNG — без этого ассета иконки в пилюле нет.
const String kFigmaProfileCoinStackPng = 'assets/figma/profile_coin_stack.png';

/// Иконка стопки монет в пилюле баланса.
class FigmaProfileCoinStack extends StatelessWidget {
  const FigmaProfileCoinStack({
    super.key,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kFigmaProfileCoinStackPng,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}

/// Форма hero на auth: вертикальная иллюстрация PNG или квадрат 1:1 (регистрация).
enum FigmaAuthHeroShape { portraitRaster, square }

/// Hero с иллюстрацией на экранах auth
class FigmaAuthHeroCard extends StatelessWidget {
  const FigmaAuthHeroCard({
    super.key,
    required this.asset,
    required this.fallbackColor,

    /// Для [FigmaAuthHeroShape.portraitRaster] по умолчанию 40; для [square] — [kFigmaAuthHeroCardRadius].
    this.borderRadius,
    this.shape = FigmaAuthHeroShape.portraitRaster,

    /// Меньше «рамка»: лёгкая тень (Figma 0-691 / лендинг).
    this.compactShadow = false,

    /// Соотношение сторон иллюстрации `width/height`. По умолчанию — PNG регистрации в Figma.
    this.aspectRatio = kFigmaRasterAspectRatio,

    /// Явный [BoxFit] для портретной карточки (например [BoxFit.contain], чтобы не кропать другой ассет).
    this.portraitAssetFit,

    /// Как квадратный слайд на лендинге 0-602: тот же расчёт стороны ([kFigmaLandingSlideVisualScale]), [kFigmaLandingSlideRadius], [BoxFit.contain], без «рамочной» тени.
    this.landingSlideStyle = false,

    /// Не сжимать иллюстрацию через [figmaLandingSlideMaxSideFromScreenHeight] — по ширине родителя (экран ввода ключа ребёнка).
    this.landingSlideBypassScreenCap = false,

    /// Вместе с [landingSlideBypassScreenCap]: hero в прямоугольнике [w × w/bleed]; [contain], без голубых полей.
    /// [fallbackColor] только для [Image.errorBuilder]. Число = плейсхолдер AspectRatio при ошибке.
    this.landingBleedLandscapeWidthOverHeight,

    /// При `MediaQuery.width > height` + bleed: высота слота **только** это значение
    /// ([kFigmaAuthBleedHeroLandscapeSlotHeight]), без масштабирования под высоту экрана.
    this.bleedWideLandscapeSlotHeight,
  });

  final String asset;
  final Color fallbackColor;
  final double? borderRadius;
  final FigmaAuthHeroShape shape;
  final bool compactShadow;
  final double aspectRatio;
  final BoxFit? portraitAssetFit;
  final bool landingSlideStyle;

  /// См. [landingSlideBypassScreenCap].
  final bool landingSlideBypassScreenCap;

  /// См. [landingBleedLandscapeWidthOverHeight].
  final double? landingBleedLandscapeWidthOverHeight;

  /// См. [bleedWideLandscapeSlotHeight].
  final double? bleedWideLandscapeSlotHeight;

  List<BoxShadow> _boxShadow() {
    return [
      BoxShadow(
        color: const Color(
          0xFF1E2D52,
        ).withValues(alpha: compactShadow ? 0.05 : 0.08),
        blurRadius: compactShadow ? 12 : 24,
        offset: Offset(0, compactShadow ? 5 : 10),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w <= 0) {
          return const SizedBox.shrink();
        }
        if (landingSlideStyle) {
          final mh = constraints.maxHeight;
          return _buildLandingSlideHero(
            context,
            w,
            maxHeight: mh.isFinite ? mh : null,
          );
        }
        return shape == FigmaAuthHeroShape.square
            ? _buildSquare(context, w)
            : _buildPortrait(context, w);
      },
    );
  }

  /// Как [AuthLandingPage] / `_SlideCard`: квадрат, скругление лендинга, целиком видно иллюстрацию.
  Widget _buildLandingSlideHero(
    BuildContext context,
    double w, {
    double? maxHeight,
  }) {
    final bleed = landingBleedLandscapeWidthOverHeight;
    if (bleed != null &&
        bleed > 0 &&
        landingSlideBypassScreenCap &&
        landingSlideStyle) {
      if (w < 8) {
        return const SizedBox.shrink();
      }
      final r = borderRadius ?? kFigmaLandingSlideRadius;
      final size = MediaQuery.sizeOf(context);
      final wideLayout = size.width > size.height;
      final slotH = bleedWideLandscapeSlotHeight;

      if (wideLayout && slotH != null && slotH > 0) {
        return Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: SizedBox(
              width: w,
              height: slotH,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                width: w,
                height: slotH,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: fallbackColor,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: kChildInk.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Портрет (и вертикальное окно): фиксированное соотношение колонки; высота от ширины.
      final portraitH = w / bleed;
      return Align(
        alignment: Alignment.topCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: SizedBox(
            width: w,
            height: portraitH,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              width: w,
              height: portraitH,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: fallbackColor,
                child: AspectRatio(
                  aspectRatio: bleed,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: kChildInk.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final maxSideFromH = figmaLandingSlideMaxSideFromScreenHeight(context);
    var side =
        landingSlideBypassScreenCap ? w : math.min(w, maxSideFromH);
    if (maxHeight != null && maxHeight.isFinite) {
      side = math.min(side, maxHeight);
    }
    if (side < 8) {
      return const SizedBox.shrink();
    }
    final r = borderRadius ?? kFigmaLandingSlideRadius;

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: side,
        height: side,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: fallbackColor,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: kChildInk.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, double w) {
    final maxH = math.min(
      MediaQuery.sizeOf(context).height * kFigmaAuthHeroMaxHeightFraction,
      kFigmaAuthHeroMaxHeightPx,
    );
    final r = borderRadius ?? 40;
    final idealH = w / aspectRatio;
    final h = math.min(idealH, maxH);
    if (h < 8) {
      return const SizedBox.shrink();
    }
    final autoCover = portraitAssetFit == null && idealH > maxH + 0.5;
    final fit = portraitAssetFit ?? (autoCover ? BoxFit.cover : BoxFit.contain);
    final alignment = portraitAssetFit != null
        ? Alignment.center
        : (autoCover ? Alignment.bottomCenter : Alignment.center);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: _boxShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: SizedBox(
          width: w,
          height: h,
          child: Image.asset(
            asset,
            fit: fit,
            width: w,
            height: h,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: fallbackColor),
          ),
        ),
      ),
    );
  }

  Widget _buildSquare(BuildContext context, double w) {
    final screenH = MediaQuery.sizeOf(context).height;
    final heightCap = math.min(
      screenH * kFigmaAuthSquareHeroMaxHeightFraction,
      kFigmaAuthSquareHeroMaxSidePx,
    );
    final side = math.min(w, heightCap);
    if (side < 8) {
      return const SizedBox.shrink();
    }
    final r = borderRadius ?? kFigmaAuthHeroCardRadius;

    final card = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: _boxShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: side,
          height: side,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: fallbackColor),
        ),
      ),
    );

    if ((w - side).abs() < 1) {
      return card;
    }
    return Align(alignment: Alignment.center, child: card);
  }
}

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

/// Общие поля и скругление полей ввода на auth-экранах.
InputDecoration figmaAuthFieldDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: 'Nunito',
      color: kChildInkMuted,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
    ),
    suffixIcon: suffixIcon,
  );
}

/// CTA по макету Figma: ниже и с более лёгкой типографикой, чем 68/w800.
class FigmaGradientButton extends StatelessWidget {
  const FigmaGradientButton({
    super.key,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.height = kFigmaLandingCtaHeight,

    /// Игнорируется, если задан [labelStyle].
    this.fontSize = kFigmaCtaFontSize,

    /// `null` — полная «таблетка» (высота/2). Иначе фиксированное скругление.
    this.cornerRadius,

    /// Задаёт типографику целиком (например [kFigmaLandingCtaTextStyle]); тогда [fontSize] не используется.
    this.labelStyle,

    /// Тень кнопки; по умолчанию одна мягкая снизу.
    this.boxShadow,

    /// Ближе к Figma «Cap height» / плотной строке.
    this.textHeightBehavior,
  });

  static const mintGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFD8F8D0), Color(0xFFC5F2C0), Color(0xFFB8E8AF)],
  );

  /// Лендинг: лёгкий вертикальный градиент (светлее сверху).
  static const mintGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE2FADC), Color(0xFFC5F2C0), Color(0xFFAFE8A5)],
  );

  static const skyGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFEAF4FC), Color(0xFFD8E9F8), Color(0xFFC8DFF2)],
  );

  static const skyGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEFF6FC), Color(0xFFD8E9F8), Color(0xFFC4DCF2)],
  );

  final String label;
  final Gradient gradient;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final double? cornerRadius;
  final TextStyle? labelStyle;
  final List<BoxShadow>? boxShadow;
  final TextHeightBehavior? textHeightBehavior;

  @override
  Widget build(BuildContext context) {
    final r = cornerRadius ?? height / 2;
    final shadows = boxShadow ?? kFigmaLandingCtaBoxShadows;
    final textStyle = labelStyle ?? kFigmaLandingCtaTextStyle;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(r),
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(r),
            splashColor: Colors.black.withValues(alpha: 0.06),
            highlightColor: Colors.black.withValues(alpha: 0.04),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    textHeightBehavior: textHeightBehavior,
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Отступы вокруг [Dialog], чтобы контент мог занять **widthFraction** ширины
/// экрана (по умолчанию 80%).
EdgeInsets figmaWideModalInsets(
  BuildContext context, {
  double widthFraction = 0.8,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final side = math.max(0.0, (w * (1.0 - widthFraction)) / 2.0);
  return EdgeInsets.fromLTRB(side, 24, side, 24);
}

/// Целевая ширина модалки как доля экрана (по умолчанию 80%).
double figmaWideModalWidth(BuildContext context, {double widthFraction = 0.8}) {
  return MediaQuery.sizeOf(context).width * widthFraction;
}

/// Красная обводка вторичной кнопки «Отмена» в модалках.
const Color kFigmaModalCancelBorder = Color(0xFFE53935);
const Color kFigmaModalCancelForeground = Color(0xFFB71C1C);

/// Прозрачная «Отмена» только с красной обводкой — под основным CTA.
class FigmaDialogCancelButton extends StatelessWidget {
  const FigmaDialogCancelButton({
    super.key,
    required this.onPressed,
    this.label = 'Отмена',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kFigmaLandingCtaHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: kFigmaModalCancelForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: const BorderSide(color: kFigmaModalCancelBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFigmaLandingCtaHeight / 2),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Две полноширинные CTA: сверху подтверждение (градиент), снизу «Отмена» с красной обводкой.
class FigmaDialogActionStack extends StatelessWidget {
  const FigmaDialogActionStack({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = 'Отмена',
    this.confirmLabel = 'Сохранить',
    this.confirmGradient,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;

  /// По умолчанию тот же мятный градиент, что у «Сохранить» на лендинге.
  final Gradient? confirmGradient;

  /// Градиент для деструктивного подтверждения («Удалить»).
  static const LinearGradient destructiveGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE8E8), Color(0xFFFFC4C4), Color(0xFFFF9E9E)],
  );

  static final TextStyle _destructiveConfirmStyle = kFigmaLandingCtaTextStyle
      .copyWith(color: const Color(0xFF5C1414));

  @override
  Widget build(BuildContext context) {
    final destructive = identical(confirmGradient, destructiveGradientVertical);
    final gradient =
        confirmGradient ?? FigmaGradientButton.mintGradientVertical;
    final confirmStyle = destructive
        ? _destructiveConfirmStyle
        : kFigmaLandingCtaTextStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigmaGradientButton(
          label: confirmLabel,
          gradient: gradient,
          height: kFigmaLandingCtaHeight,
          labelStyle: confirmStyle,
          boxShadow: kFigmaLandingCtaBoxShadows,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          onTap: onConfirm,
        ),
        const SizedBox(height: 12),
        FigmaDialogCancelButton(onPressed: onCancel, label: cancelLabel),
      ],
    );
  }
}

/// Шапка auth: тот же верхний ритм и типографика, что «CLAN CAPITAL» на лендинге 0-602,
/// заголовки **по центру**; ряд «назад» — [Stack], чтобы заголовок был в центре экрана.
class FigmaAuthDoubleDeckHeader extends StatelessWidget {
  const FigmaAuthDoubleDeckHeader({
    super.key,
    this.flowBanner,
    required this.navTitle,
    required this.onBack,
    this.horizontalPadding = kFigmaAuthScreenPaddingH,
  });

  /// Верхняя строка (например **УЧАСТНИК**). `null` или `''` — скрыть.
  final String? flowBanner;
  final String navTitle;
  final VoidCallback onBack;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final banner = flowBanner?.trim();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: kFigmaLandingTitleTopSpacer),
          if (banner != null && banner.isNotEmpty) ...[
            Text(
              banner,
              textAlign: TextAlign.center,
              style: kFigmaAuthLandingTitleStyle,
            ),
            const SizedBox(height: kFigmaLandingHeaderToCarouselGap),
          ],
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 48,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: kFigmaAuthTitleBlack,
                      size: 24,
                    ),
                    onPressed: onBack,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    navTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: kFigmaAuthLandingTitleStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Точки-«шары» как на лендинге / Figma 0-691.
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
                ? kFigmaAuthTitleBlack
                : kFigmaAuthTitleBlack.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// Единый адаптивный hero на всех auth-экранах. Настройки — [figma_auth_hero.dart].
class FigmaAuthHero extends StatelessWidget {
  const FigmaAuthHero({
    super.key,
    required this.asset,
    this.fallbackColor = Colors.transparent,
    this.showDots = false,
    this.dotCount = 3,
    this.activeDotIndex = 0,
    this.centerInSlot = true,
  });

  final String asset;
  final Color fallbackColor;
  final bool showDots;
  final int dotCount;
  final int activeDotIndex;
  final bool centerInSlot;

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

        final mq = MediaQuery.sizeOf(context);
        final refShort = math.min(mq.width, mq.height);
        final side = figmaAuthHeroSide(
          maxWidth: maxW,
          maxHeight: maxH,
          referenceShortestSide: refShort,
        );
        if (side < 8) {
          return const SizedBox.shrink();
        }

        final image = ClipRRect(
          borderRadius:
              BorderRadius.circular(kFigmaAuthHeroCornerRadius),
          child: Image.asset(
            asset,
            width: side,
            height: side,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: fallbackColor,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 42,
                color: kChildInkMuted.withValues(alpha: 0.45),
              ),
            ),
          ),
        );

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: image),
            if (showDots) ...[
              SizedBox(height: kFigmaLandingSlideToDotsGap),
              FigmaAuthCarouselDots(
                count: dotCount,
                activeIndex: activeDotIndex,
              ),
            ],
          ],
        );

        if (maxH != null && maxH > side + 8) {
          return centerInSlot
              ? Center(child: column)
              : Align(alignment: Alignment.topCenter, child: column);
        }
        return column;
      },
    );
  }
}

@Deprecated('Use FigmaAuthHero')
typedef FigmaAuthHeroCarouselSlot = FigmaAuthHero;

/// Фон экранов входа/регистрации — как на лендинге Figma (градиент, облака, боке).
class FigmaAuthScreenBackground extends StatelessWidget {
  const FigmaAuthScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FCFF), Color(0xFFEFF6FB), Color(0xFFE6F0F8)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/figma/cloud_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            color: Colors.white.withValues(alpha: 0.55),
            colorBlendMode: BlendMode.softLight,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const CustomPaint(painter: FigmaBokehPainter()),
        ],
      ),
    );
  }
}

/// Боке-светлячки на фоне auth-экранов.
class FigmaBokehPainter extends CustomPainter {
  const FigmaBokehPainter();

  static const _spots = <(double x, double y, double r, double a)>[
    (0.12, 0.18, 42, 0.35),
    (0.78, 0.12, 56, 0.28),
    (0.88, 0.42, 34, 0.22),
    (0.08, 0.52, 28, 0.25),
    (0.62, 0.68, 48, 0.20),
    (0.32, 0.82, 38, 0.18),
    (0.92, 0.86, 24, 0.16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final spot in _spots) {
      final center = Offset(spot.$1 * size.width, spot.$2 * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: spot.$4),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: spot.$3));
      canvas.drawCircle(center, spot.$3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Белая «таблетка» с мягкой тенью под полем ввода (Figma).
class FigmaAuthInputShell extends StatelessWidget {
  const FigmaAuthInputShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2D52).withValues(alpha: 0.10),
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Glow под CTA «Обратная задача» в дашборде ребёнка (Figma node 0-137).
const List<BoxShadow> kFigmaMintCtaGlow = [
  BoxShadow(
    color: Color.fromRGBO(230, 247, 217, 0.35),
    blurRadius: 50,
    offset: Offset(0, 20),
  ),
  BoxShadow(
    color: Color.fromRGBO(212, 255, 179, 0.35),
    blurRadius: 20,
    offset: Offset(0, 13),
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
    this.fontWeight = FontWeight.w800,
    this.icon,
    this.boxShadow,
    this.border,
    this.labelStyle,
  });

  final VoidCallback? onTap;
  final String label;
  final Color bg;
  final Color fg;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final IconData? icon;
  final List<BoxShadow>? boxShadow;
  final BoxBorder? border;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedLabelStyle =
        labelStyle ??
        TextStyle(
          fontFamily: 'Nunito',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: fg,
        );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
          border: border,
          boxShadow: boxShadow ?? kSoftButtonShadow(bg),
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
                  Text(label, style: resolvedLabelStyle),
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
  const CoinStackIcon({
    super.key,
    this.size = 24,
    this.color = kChildBrandBlue,
  });
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
  const CloudBackground({super.key, required this.child, this.opacity = 0.15});
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
  final Color?
  borderColor; // kept for API compat, not used (neuCard has no border)
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
        child: Padding(padding: padding, child: child),
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
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Высота белой «капсулы» навигации (видимый pill).
  static const double capsuleHeight = 96;

  /// Отступ от низа слота scaffold до нижней границы экрана (под системный бар).
  static const double capsuleSlotBottomPadding = 14;

  /// Зона экрана, закрытая нижней навигацией — нужен такой же отступ в скролле контента,
  /// чтобы карточки (напр. «Обратная задача») можно было дороллить над плашкой.
  static double scrollBottomClearance(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.viewPadding.bottom, mq.padding.bottom);
    return capsuleHeight + capsuleSlotBottomPadding + bottomInset;
  }

  /// Ширина плашки в макете 311 px; не больше доступной области.
  static double pillWidthForConstraints(double maxWidth) {
    return math.min(
      maxWidth,
      math.max(
        kFigmaChildBottomBarMaxWidth.toDouble(),
        math.min(460.0, maxWidth * 0.78),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.viewPadding.bottom, mq.padding.bottom);
    return SizedBox(
      height: capsuleHeight + capsuleSlotBottomPadding + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          capsuleSlotBottomPadding + bottomInset,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final navWidth = pillWidthForConstraints(constraints.maxWidth);
              return SizedBox(
                width: navWidth,
                height: capsuleHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(
                      color: kFigmaChildNavPillBorder,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChildHomeNavColumn(
                            label: 'Дом',
                            selected: currentIndex == 0,
                            onTap: () => onSelected(0),
                            home: true,
                          ),
                          const SizedBox(width: 28),
                          _ChildHomeNavColumn(
                            label: 'Биржа',
                            selected: currentIndex == 1,
                            onTap: () => onSelected(1),
                            asset: 'assets/figma/nav_assignment.svg',
                          ),
                          const SizedBox(width: 28),
                          _ChildHomeNavColumn(
                            label: 'Магазин',
                            selected: currentIndex == 2,
                            onTap: () => onSelected(2),
                            asset: 'assets/figma/nav_shop.svg',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChildHomeNavColumn extends StatelessWidget {
  const _ChildHomeNavColumn({
    required this.label,
    required this.selected,
    required this.onTap,
    this.home = false,
    this.asset,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool home;
  final String? asset;

  static const double _kCircle = 52;
  static const double _kIcon = 26;

  @override
  Widget build(BuildContext context) {
    final blue = kFigmaChildScreenBlue;
    final muted = kFigmaChildNavLabelMuted;
    final iconColor = selected ? Colors.white : muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: _kCircle,
                height: _kCircle,
                decoration: BoxDecoration(
                  color: selected ? blue : Colors.white,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(
                          color: muted.withValues(alpha: 0.39),
                          width: 1,
                        ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: blue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: home
                    ? SvgPicture.asset(
                        selected
                            ? 'assets/figma/nav_home_filled.svg'
                            : 'assets/figma/nav_home_outline.svg',
                        width: _kIcon,
                        height: _kIcon,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      )
                    : SvgPicture.asset(
                        asset!,
                        width: _kIcon,
                        height: _kIcon,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? blue : muted,
                  height: 1.1,
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
      backgroundColor: Colors.transparent,
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
            fontFamily: 'Nunito',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kChildBrandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(kFigmaLandingCtaHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFigmaLandingCtaHeight / 2),
          ),
          elevation: 4,
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kChildBrandBlue,
          side: const BorderSide(color: kChildBrandBlue, width: 1.4),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
