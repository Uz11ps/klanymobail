import 'package:flutter/material.dart';

/// Layout tokens for Figma [node 150:1125](https://www.figma.com/design/kwVuEbSWPdrTEFsrIvZVB3/Untitled?node-id=150-1125).
abstract final class EconomyFigmaLayout {
  static const Color bg = Color(0xFFFDFEFE);
  static const Color titleBlue = Color(0xFF4563B1);
  static const Color titleMarker = Color(0xFFF9E8A5);
  static const Color tabActiveMint = Color(0xFFD9F6C2);
  static const Color tabActiveGrey = Color(0xFFEFEFEF);

  static const double hMargin = 19;
  static const double dividerHeight = 2;
  static const double dividerVerticalPad = 18;

  /// Как на главной (`ListView` padding top: 16): отступ заголовка от верха SafeArea.
  static const EdgeInsets screenHeaderPad = EdgeInsets.fromLTRB(20, 16, 19, 16);
  static const EdgeInsets balancePad = EdgeInsets.fromLTRB(19, 0, 19, 0);
  static const EdgeInsets coinCardOuterPad = EdgeInsets.fromLTRB(19, 0, 19, 0);
  static const EdgeInsets coinCardInnerPad = EdgeInsets.symmetric(
    horizontal: 15,
    vertical: 20,
  );
  static const EdgeInsets birzhaHeaderPad = EdgeInsets.fromLTRB(19, 0, 19, 10);
  static const EdgeInsets birzhaTabsPad = EdgeInsets.fromLTRB(19, 0, 19, 14);
  static const EdgeInsets listHorizontalPad = EdgeInsets.fromLTRB(19, 14, 19, 0);

  static const double walletRowHeight = 118;
  static const double walletChipPad = 10;
  static const double walletAvatar = 60;
  static const double walletAvatarGap = 8;
  static const double walletLabelWidth = 72;

  static const double coinIconW = 32;
  static const double coinIconH = 29;
  static const double balanceFontSize = 40;
  static const double rublesFontSize = 16;

  static const double sectionTitleSize = 20;
  static const double tabHeight = 54;
  static const double tabFontSize = 20;
  static const double tabGap = 10;

  static const double coinCardRadius = 25;
  static const double circleBtnSize = 50;
  static const double shopBtnSize = 44;

  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    height: 1.0,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: sectionTitleSize,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    height: 1.0,
  );

  static const TextStyle balanceStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: balanceFontSize,
    fontWeight: FontWeight.w800,
    color: titleBlue,
    height: 1.0,
  );

  static const TextStyle walletLabelStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    height: 1.0,
  );

  static const TextStyle tabLabelStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: tabFontSize,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  );

  static const TextStyle reviewSectionHintStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0x99000000),
    height: 1.2,
  );
}
