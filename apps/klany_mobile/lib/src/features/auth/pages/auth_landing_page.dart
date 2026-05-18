import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';

/// Лендинг [0-602](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-602&m=dev): заголовок → карусель 1:1 → точки → [воздух] → CTA.
class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  static const _slides = <String>[
    'assets/figma/slide_motivation.png',
    'assets/figma/slide_team.png',
    'assets/figma/slide_capital.png',
  ];

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
                const Expanded(
                  child: FigmaAuthHeroSection(
                    child: FigmaAuthHeroCarousel(
                      assets: _slides,
                      fallbackColor: kBrandMint,
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
