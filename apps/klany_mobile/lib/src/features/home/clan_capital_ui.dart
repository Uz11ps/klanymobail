import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kChildBrandBlue = Color(0xFF2E63D8);
const Color kChildInk = Color(0xFF1E2D52);
const Color _kNeuShadowDark = Color(0xFF1A3D6B);

abstract class ClanCapitalUi {
  // Exact neomorphic card decoration from APK.
  // Light shadow offset=(-4,-4) blurRadius=10, dark shadow offset=(8,10) blurRadius=20.
  static BoxDecoration neuCard({Color? color, double radius = 26}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95),
          blurRadius: 10,
          offset: const Offset(-4, -4),
        ),
        BoxShadow(
          color: _kNeuShadowDark.withValues(alpha: 0.09),
          blurRadius: 20,
          offset: const Offset(8, 10),
        ),
      ],
    );
  }

  // Brand logo header: "CLAN CAPITAL" (Nunito w900 22px blue) + optional subtitle.
  static Widget logoHeader(String? subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLAN CAPITAL',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kChildBrandBlue,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kChildInk,
            ),
          ),
      ],
    );
  }
}
