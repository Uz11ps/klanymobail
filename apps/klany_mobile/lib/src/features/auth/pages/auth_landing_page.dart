import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';

/// Лендинг [0-602](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-602&m=dev): заголовок → карусель 1:1 → точки → [воздух] → CTA.
class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  late final PageController _pageController = PageController(
    viewportFraction: 1,
  );
  int _slide = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_slide + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static const _slides = <String>[
    'assets/figma/slide_motivation.png',
    'assets/figma/slide_team.png',
    'assets/figma/slide_capital.png',
  ];

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final topInset = math.max(safe.top, kFigmaLandingMinTopInset);
    final bottomInset = math.max(safe.bottom, kFigmaLandingMinBottomInset);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FigmaAuthScreenBackground(),
          Padding(
            padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kFigmaLandingTitleTopSpacer),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: kFigmaLandingContentPaddingH,
                  ),
                  child: Text(
                    'CLAN CAPITAL',
                    textAlign: TextAlign.start,
                    style: kFigmaAuthLandingTitleStyle,
                  ),
                ),
                const SizedBox(height: kFigmaLandingHeaderToCarouselGap),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kFigmaLandingContentPaddingH,
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          const dotsBlock =
                              kFigmaLandingSlideToDotsGap +
                                  kFigmaLandingDotsDiameter;
                          // Слот от [Expanded] уже отражает доступную высоту; квадрат — макс. вписанный в (ширина × высота слота).
                          final maxSideBySlot = math.max(
                            0.0,
                            c.maxHeight - dotsBlock,
                          );
                          final side = math.min(c.maxWidth, maxSideBySlot);

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
                                  itemCount: _slides.length,
                                  onPageChanged: (i) =>
                                      setState(() => _slide = i),
                                  itemBuilder: (_, i) {
                                    return Center(
                                      child: SizedBox(
                                        width: side,
                                        height: side,
                                        child: _SlideCard(
                                          asset: _slides[i],
                                          borderRadius:
                                              kFigmaLandingSlideRadius,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(
                                height: kFigmaLandingSlideToDotsGap,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_slides.length, (i) {
                                  final active = i == _slide;
                                  return AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: active ? 7 : 5,
                                    height: active ? 7 : 5,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? kFigmaAuthTitleBlack
                                          : kFigmaAuthTitleBlack
                                              .withValues(alpha: 0.22),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: kFigmaLandingDotsToButtonsGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kFigmaLandingContentPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!Env.hasApiConfig) ...[
                        ChildSoftCard(
                          color: const Color(0xFFFFF4D6),
                          padding: const EdgeInsets.all(12),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFB5761A),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Демо-режим: заполните API_BASE_URL в .env',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Color(0xFF6A4A10),
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FigmaGradientButton(
                        label: 'Я - Глава Клана',
                        gradient: FigmaGradientButton.mintGradientVertical,
                        height: kFigmaLandingCtaHeight,
                        labelStyle: kFigmaLandingCtaTextStyle,
                        boxShadow: kFigmaLandingCtaBoxShadows,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        onTap: () => context.go('/auth/parent/sign-in'),
                      ),
                      const SizedBox(height: 16),
                      FigmaGradientButton(
                        label: 'Я - Участник Клана',
                        gradient: FigmaGradientButton.skyGradientVertical,
                        height: kFigmaLandingCtaHeight,
                        labelStyle: kFigmaLandingCtaTextStyle,
                        boxShadow: kFigmaLandingCtaBoxShadows,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        onTap: () => context.go('/auth/child/sign-in'),
                      ),
                    ],
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

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.asset,
    required this.borderRadius,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String asset;
  final double borderRadius;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        asset,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => ColoredBox(
          color: kBrandMint,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: kChildInk.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}
