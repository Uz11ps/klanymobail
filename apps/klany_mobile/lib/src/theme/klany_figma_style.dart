import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Общие токены макетов Figma — подключай один раз и не дублируй «магические числа».
///
/// - [node 0-81](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-81&m=dev) — главный экран родителя (капсула, аватары, инфо-панель)
/// - [node 0-602](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-602&m=dev) — лендинг
/// - [node 0-1215](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-1215&m=dev) — регистрация
///
/// Виджеты и палитра: `import '.../features/home/child_soft_ui.dart';` (реэкспорт этого файла).

// ─── Лендинг 0-602 ─────────────────────────────────────────────────────────

/// Горизонтальные поля лендинга (заголовок, карусель, CTA).
const double kFigmaLandingContentPaddingH = 12;

/// Минимум отступа сверху как на лендинге 0-602 (в т.ч. web, где safe = 0).
const double kFigmaLandingMinTopInset = 36;

/// Минимум отступа снизу как на лендинге.
const double kFigmaLandingMinBottomInset = 44;

/// Воздух под верхним inset до заголовка «CLAN CAPITAL» / auth-заголовков.
const double kFigmaLandingTitleTopSpacer = 6;

/// Квадрат слайда: макс. сторона как доля высоты экрана.
const double kFigmaLandingMaxSlideHeightFraction = 0.70;

/// Жёсткий потолок стороны квадрата (px) — шире, чем раньше, чтобы на телефоне не крошилась.
const double kFigmaLandingMaxSlideHeightPx = 600;

// ─── Альбомная ориентация: размер от геометрии окна, без «магического» жёсткого px ─

/// Доля от **короткой** стороны окна [min(w,h)] — на широком web квадрат масштабируется вместе с окном.
/// Портретная ветка [figmaLandingSlideMaxSideFromScreenHeight] не использует эти константы.
const double kFigmaLandingLandscapeSlideShortestFraction = 0.48;

/// Доля от **высоты** окна в альбоме — ограничение сверху, чтобы не вылезать за экран по вертикали.
const double kFigmaLandingLandscapeSlideHeightFraction = 0.58;

/// Мягкий абсолютный потолок стороны (очень широкие мониторы).
const double kFigmaLandingLandscapeSlideSideCeilPx = 480;

/// Лёгкий множитель в альбоме (ниже портретного [kFigmaLandingSlideVisualScale]).
const double kFigmaLandingSlideVisualScaleLandscape = 1.06;

/// Макс. сторона квадрата слайда из [MediaQuery]: портрет — доля высоты; альбом — min(доля короткой стороны, доля высоты, потолок).
double figmaLandingSlideMaxSideFromScreenHeight(BuildContext context) {
  final landscape =
      MediaQuery.orientationOf(context) == Orientation.landscape;
  final size = MediaQuery.sizeOf(context);
  final h = size.height;
  if (landscape) {
    final shortest = math.min(size.width, size.height);
    final raw = math.min(
      math.min(
        shortest * kFigmaLandingLandscapeSlideShortestFraction,
        h * kFigmaLandingLandscapeSlideHeightFraction,
      ),
      kFigmaLandingLandscapeSlideSideCeilPx,
    );
    return raw * kFigmaLandingSlideVisualScaleLandscape;
  }
  return math.min(
        h * kFigmaLandingMaxSlideHeightFraction,
        kFigmaLandingMaxSlideHeightPx,
      ) *
      kFigmaLandingSlideVisualScale;
}

/// Зазор под «CLAN CAPITAL» до блока карусели.
const double kFigmaLandingHeaderToCarouselGap = 20;

/// Скругление карточки слайда.
const double kFigmaLandingSlideRadius = 28;

/// Зазор от слайда до индикаторов.
const double kFigmaLandingSlideToDotsGap = 8;

/// Диаметр активной точки (ряд индикаторов); для расчёта высоты блока под слайдом.
const double kFigmaLandingDotsDiameter = 7;

/// Отступ после точек до блока кнопок.
const double kFigmaLandingDotsToButtonsGap = 20;

/// Общий множитель размера квадрата иллюстрации (лендинг и регистрация): тот же стиль, крупнее объект.
const double kFigmaLandingSlideVisualScale = 1.22;

/// Высота CTA на лендинге (запас под Nunito 24 / w700).
const double kFigmaLandingCtaHeight = 72;

/// Текст на кнопках лендинга — как в Figma (Nunito, 24, Bold / w700, line 100%).
const TextStyle kFigmaLandingCtaTextStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: Color(0xFF000000),
  height: 1.0,
  letterSpacing: 0,
);

/// Мягкая «объёмная» тень под CTA лендинга (soft UI).
const List<BoxShadow> kFigmaLandingCtaBoxShadows = [
  BoxShadow(
    color: Color(0x241E2D52),
    blurRadius: 20,
    offset: Offset(0, 10),
    spreadRadius: -4,
  ),
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 8,
    offset: Offset(0, 3),
  ),
  BoxShadow(
    color: Color(0x59FFFFFF),
    blurRadius: 0,
    offset: Offset(0, -1),
    spreadRadius: 0,
  ),
];

// ─── Единая первичная CTA в auth (как лендинг [0-602](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-602&m=dev)) ──

const double kFigmaAuthPrimaryCtaHeight = kFigmaLandingCtaHeight;

// ─── PNG hero регистрации (989×1200) ────────────────────────────────────────

const double kFigmaRasterAspectRatio = 989 / 1200;

// ─── Hero / формы (регистрация, не лендинг) ──────────────────────────────

const double kFigmaAuthHeroMaxHeightFraction = 0.42;
const double kFigmaAuthHeroMaxHeightPx = 340;

const double kFigmaAuthScreenPaddingH = 16;

/// Вертикальный зазор между контентом и safe area под кастомным аппбаром.
const double kFigmaAuthScreenContentTop = 6;

/// Квадратный hero ([0-691](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-691&t=dv1Tkw30lvNzKssf-4)): крупнее, ближе к лендингу.
const double kFigmaAuthSquareHeroMaxHeightFraction = 0.54;
const double kFigmaAuthSquareHeroMaxSidePx = 460;

/// Скругление hero карточки (Figma 0-691): без тяжёлой «коробки».
const double kFigmaAuthHeroCardRadius = 20;

/// Макет «iPhone 17 - 11» (ввод ключа ребёнка): 390×844, hero 397×397, inset слева 18.
const double kFigmaAuthChildKeyFrameWidth = 390;
const double kFigmaAuthChildKeyFrameHeight = 844;
const double kFigmaAuthChildKeyHeroSidePx = 397;
const double kFigmaAuthChildKeyHeroInsetH = 18;

/// Сторона квадратного hero: `397 × (ширина / 390)`, как в Figma; на низком слоте — по высоте.
double figmaAuthChildKeyHeroSide({
  required double maxWidth,
  double? maxHeight,
}) {
  if (maxWidth < 8) return 0;
  final wScale = maxWidth / kFigmaAuthChildKeyFrameWidth;
  var side = kFigmaAuthChildKeyHeroSidePx * wScale;
  if (maxHeight != null && maxHeight.isFinite && maxHeight > 0) {
    side = math.min(side, maxHeight);
  }
  return side < 8 ? 0 : side;
}

// Отступы формы под макет 0-1215
const double kFigmaAuthHeroToFormGap = 20;

/// После hero на экране ввода ключа ребёнка.
const double kFigmaAuthBleedHeroToFormGap = 20;
const double kFigmaAuthLabelToFieldGap = 6;
const double kFigmaAuthFieldStackGap = 16;
const double kFigmaAuthBeforePrimaryCtaGap = 24;

// ─── Типографика / CTA defaults ────────────────────────────────────────────

const Color kFigmaAuthTitleBlack = Color(0xFF000000);

/// Заголовок как «CLAN CAPITAL» на лендинге (крупный, жирный, чёрный).
/// На экранах auth использовать **по центру** (`textAlign: TextAlign.center`).
const TextStyle kFigmaAuthLandingTitleStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 28,
  fontWeight: FontWeight.w900,
  color: kFigmaAuthTitleBlack,
  letterSpacing: 0.4,
  height: 1.1,
);

/// Основной цвет текста в полях (как [kChildInk], без импорта home-слоя).
const Color kFigmaAuthBodyInk = Color(0xFF1E2D52);

/// Заголовок экрана («Регистрация») — не w900, плотный заголовок как в Figma.
const TextStyle kFigmaAuthScreenTitleStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 18,
  fontWeight: FontWeight.w800,
  color: kFigmaAuthTitleBlack,
  height: 1.2,
);

/// Верхний баннер потока (Figma): **РЕГИСТРАЦИЯ**, **ВХОД** — по центру, капс.
const TextStyle kFigmaAuthFlowBannerStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 12,
  fontWeight: FontWeight.w800,
  color: kFigmaAuthTitleBlack,
  letterSpacing: 1.35,
  height: 1.15,
);

/// Отступ от баннера потока до ряда «назад + заголовок страницы».
const double kFigmaAuthFlowBannerToNavGap = 16;

/// Подпись к полю (Email, …).
const TextStyle kFigmaAuthFieldLabelStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: kFigmaAuthTitleBlack,
  height: 1.25,
);

/// Текст в инпуте.
const TextStyle kFigmaAuthInputTextStyle = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: kFigmaAuthBodyInk,
);

const double kFigmaCtaHeight = 56;
const double kFigmaCtaFontSize = 17;

// ─── Главный экран родителя [0-81](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-81&m=dev) ─

/// Нижняя «капсула»: визуально уже экрана — центрируется с этим максимумом.
const double kFigmaParentBottomBarMaxWidth = 340;

/// Высота области нижнего бара (без SafeArea).
const double kFigmaParentBottomBarHeight = 62;

/// Центральная кнопка «Дом»: активная / неактивная.
const double kFigmaParentNavHomeSelected = 44;
const double kFigmaParentNavHomeIdle = 40;

/// Мягкая тень карточек инфо-панели (ближе к макету, чем одна тёмная тень).
const List<BoxShadow> kFigmaInfoPanelCardShadows = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 8),
    spreadRadius: -2,
  ),
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  ),
];

/// Кольцо выбранного участника на главной.
const double kFigmaMemberAvatarRing = 3;
const double kFigmaMemberAvatarDiameter = 72;
