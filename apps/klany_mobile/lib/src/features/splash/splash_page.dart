import 'package:flutter/material.dart';

import '../home/child_soft_ui.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B78E0),
                      kChildBrandBlue,
                      kChildBrandBlueDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D2E63D8),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_moon,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'CLAN CAPITAL',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: kChildBrandBlue,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Финансовый клан для семьи',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: kChildInkMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  color: kChildBrandBlue,
                  backgroundColor: Color(0xFFD7E1F2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
