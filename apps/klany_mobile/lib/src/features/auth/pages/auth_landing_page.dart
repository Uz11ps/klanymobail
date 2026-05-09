import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';

class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  final _pageController = PageController(viewportFraction: 0.88);
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

  static const _slides = <_LandingSlide>[
    _LandingSlide(
      asset: 'assets/figma/slide_motivation.png',
      bg: kBrandMint,
      title: 'Мотивируй\nделом, а не\nсловом',
    ),
    _LandingSlide(
      asset: 'assets/figma/slide_team.png',
      bg: kBrandMint,
      title: 'Управляй\nэффективностью и\nмотивацией Клана',
    ),
    _LandingSlide(
      asset: 'assets/figma/slide_capital.png',
      bg: kBrandMint,
      title: 'Расти капитал\nвместе с\nдетьми',
    ),
  ];

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCloud,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/figma/cloud_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.55,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 24),
                child: Text(
                  'CLAN CAPITAL',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kChildInk,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _slide = i),
                  itemBuilder: (_, i) => _SlideCard(slide: _slides[i]),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _slide;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? kChildInk
                          : kChildInk.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!Env.hasApiConfig) ...[
                      ChildSoftCard(
                        color: const Color(0xFFFFF4D6),
                        padding: const EdgeInsets.all(12),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFFB5761A), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Демо-режим: заполните API_BASE_URL в .env',
                                style: TextStyle(
                                  color: Color(0xFF6A4A10),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SoftButton(
                      label: 'Я - Глава Клана',
                      bg: kBrandMint,
                      fg: kChildInk,
                      onTap: () => context.go('/auth/parent/sign-in'),
                    ),
                    const SizedBox(height: 14),
                    SoftButton(
                      label: 'Я - Участник Клана',
                      bg: kBrandSky,
                      fg: kChildInk,
                      onTap: () => context.go('/auth/child/sign-in'),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/auth/parent/sign-up'),
                        style: TextButton.styleFrom(
                          foregroundColor: kChildBrandBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text(
                          'Создать новый клан',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSlide {
  const _LandingSlide({
    required this.asset,
    required this.bg,
    required this.title,
  });
  final String asset;
  final Color bg;
  final String title;
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});
  final _LandingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: BoxDecoration(
            color: slide.bg,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                slide.asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => Container(color: slide.bg),
              ),
              // Subtle dim overlay so white text is readable on photo
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Text(
                    slide.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
