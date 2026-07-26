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
  static const double fabVisualSize = 73;
  static const double fabHitSize = 88;
  static const Color fabFill = Color(0xFF4563B1);

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
}
