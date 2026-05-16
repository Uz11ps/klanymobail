import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';

/// Figma landing (node 0-602): carousel peek, gradient CTAs, bokeh background.
class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  static const _carouselViewport = 0.84;
  static const _slideAspectRatio = 335 / 400;
  static const _ctaHorizontalPadding = 16.0;

  late final PageController _pageController = PageController(
    viewportFraction: _carouselViewport,
  );
  int _slide = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_slide + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
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
    final size = MediaQuery.sizeOf(context);
    final slideWidth = size.width * _carouselViewport;
    final slideHeight = math.min(
      slideWidth / _slideAspectRatio,
      size.height * 0.48,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LandingBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 24, right: 20),
                  child: Text(
                    'CLAN CAPITAL',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF000000),
                      letterSpacing: 0.4,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: slideHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              padEnds: true,
                              clipBehavior: Clip.none,
                              itemCount: _slides.length,
                              onPageChanged: (i) => setState(() => _slide = i),
                              itemBuilder: (_, i) {
                                final distance =
                                    (_slide - i).abs().toDouble();
                                final scale =
                                    (1 - distance * 0.05).clamp(0.95, 1.0);
                                return AnimatedScale(
                                  scale: scale,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: _SlideCard(asset: _slides[i]),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _slide;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: active ? 9 : 8,
                            height: active ? 9 : 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF1E2A3D)
                                  : const Color(0xFF1E2A3D)
                                      .withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _ctaHorizontalPadding,
                    0,
                    _ctaHorizontalPadding,
                    12 + bottomInset,
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
                        gradient: FigmaGradientButton.mintGradient,
                        onTap: () => context.go('/auth/parent/sign-in'),
                      ),
                      const SizedBox(height: 16),
                      FigmaGradientButton(
                        label: 'Я - Участник Клана',
                        gradient: FigmaGradientButton.skyGradient,
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

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FCFF),
            Color(0xFFEFF6FB),
            Color(0xFFE6F0F8),
          ],
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
          const CustomPaint(painter: _BokehPainter()),
        ],
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  const _BokehPainter();

  static const _spots = <_BokehSpot>[
    _BokehSpot(0.12, 0.18, 42, 0.35),
    _BokehSpot(0.78, 0.12, 56, 0.28),
    _BokehSpot(0.88, 0.42, 34, 0.22),
    _BokehSpot(0.08, 0.52, 28, 0.25),
    _BokehSpot(0.62, 0.68, 48, 0.20),
    _BokehSpot(0.32, 0.82, 38, 0.18),
    _BokehSpot(0.92, 0.86, 24, 0.16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final spot in _spots) {
      final center = Offset(spot.x * size.width, spot.y * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: spot.opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: spot.radius),
        );
      canvas.drawCircle(center, spot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BokehSpot {
  const _BokehSpot(this.x, this.y, this.radius, this.opacity);
  final double x;
  final double y;
  final double radius;
  final double opacity;
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2D52).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          cacheWidth: 1200,
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
      ),
    );
  }
}
