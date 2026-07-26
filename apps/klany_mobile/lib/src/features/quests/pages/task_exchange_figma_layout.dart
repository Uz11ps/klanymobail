import 'package:flutter/material.dart';

import '../../home/parent_screen_header.dart';

/// Figma file YsSajeAgXSHK88ETbeV4N9 — экраны 1:1431, 1:1495, 1:1569.
abstract final class TaskExchangeFigmaLayout {
  static const Color tabActiveFill = Color(0xFFBFDBFF);
  static const Color metaGray = Color(0xFF666666);

  static const double hMargin = 19;
  static const EdgeInsets headerPad = ParentScreenHeaderLayout.padding;
  static const EdgeInsets tabsPad = EdgeInsets.fromLTRB(19, 8, 19, 12);
  static const EdgeInsets listPad = EdgeInsets.fromLTRB(19, 0, 19, 100);

  static const double tabHeight = 54;
  static const double tabRadius = 40;
  static const double tabGap = 10;
  static const double cardRadius = 19;
  static const double fabHitSize = 64;
  static const double fabPlusSize = 20;
  static const Color fabFill = Color(0xFF4563B1);

  /// Пастельные фоны карточек (Figma 1:1431 / child биржа 0:305+).
  static const Color cardSky = Color(0xFFC1DCF5);
  static const Color cardMint = Color(0xFFD9F6C2);
  static const Color cardLavender = Color(0xFFD8CBF7);

  static const List<Color> cardPalette = [cardSky, cardMint, cardLavender];

  static Color cardColorForKey(String key) =>
      cardPalette[key.hashCode.abs() % cardPalette.length];

  static List<BoxShadow> cardShadows(Color bg, {double scale = 1}) {
    if (bg == cardMint) {
      return [
        BoxShadow(
          color: const Color.fromRGBO(222, 247, 203, 0.35),
          blurRadius: 50 * scale,
          offset: Offset(0, 20 * scale),
        ),
        BoxShadow(
          color: const Color.fromRGBO(173, 211, 165, 0.35),
          blurRadius: 20 * scale,
          offset: Offset(0, 13 * scale),
        ),
      ];
    }
    if (bg == cardLavender) {
      return [
        BoxShadow(
          color: const Color.fromRGBO(216, 203, 247, 0.35),
          blurRadius: 50 * scale,
          offset: Offset(0, 20 * scale),
        ),
        BoxShadow(
          color: const Color.fromRGBO(179, 165, 211, 0.35),
          blurRadius: 20 * scale,
          offset: Offset(0, 13 * scale),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color.fromRGBO(193, 220, 255, 0.35),
        blurRadius: 50 * scale,
        offset: Offset(0, 20 * scale),
      ),
      BoxShadow(
        color: const Color.fromRGBO(191, 219, 255, 0.35),
        blurRadius: 20 * scale,
        offset: Offset(0, 10 * scale),
      ),
    ];
  }

  static const TextStyle titleStyle = ParentScreenHeaderLayout.titleStyle;

  static const TextStyle tabActiveStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  );

  static const TextStyle tabIdleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  );

  static const TextStyle cardCoinsStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black,
  );

  static const TextStyle cardCoinsBoldStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static const TextStyle metaStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: metaGray,
  );

  static const TextStyle deadlineStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Colors.black,
  );

  static const Color deadlineUrgent = Color(0xFF8B1A1A);

  static DateTime? resolveDeadline({
    DateTime? dueAt,
    int? timeLimitMinutes,
    DateTime? assigneeSince,
    required DateTime createdAt,
  }) {
    if (dueAt != null) return dueAt.toLocal();
    if (timeLimitMinutes != null && timeLimitMinutes > 0) {
      final base = (assigneeSince ?? createdAt).toLocal();
      return base.add(Duration(minutes: timeLimitMinutes));
    }
    return null;
  }

  static String remainingLabel(DateTime deadline, [DateTime? now]) {
    final clock = (now ?? DateTime.now()).toLocal();
    final remaining = deadline.toLocal().difference(clock);
    if (remaining.isNegative) return 'Просрочено';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    return 'Осталось ${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static bool isDeadlineUrgent(DateTime deadline, [DateTime? now]) {
    final clock = (now ?? DateTime.now()).toLocal();
    final remaining = deadline.toLocal().difference(clock);
    return !remaining.isNegative && remaining.inMinutes < 5;
  }
}
