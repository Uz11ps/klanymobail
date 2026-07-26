import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Единая шапка родительских экранов: «назад» в фиксированной точке слева, заголовок по центру экрана.
abstract final class ParentScreenHeaderLayout {
  static const double barHeight = 48;
  static const double backButtonSize = 48;
  static const double backIconSize = 24;
  static const double sideSlotWidth = 48;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(19, 16, 19, 12);

  /// Когда родительский [ListView] уже задаёт горизонтальный inset ([hMargin]).
  static const EdgeInsets paddingInInset = EdgeInsets.fromLTRB(0, 16, 0, 12);

  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    height: 1.0,
  );
}

class ParentScreenHeader extends StatelessWidget {
  const ParentScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showBackButton = true,
    this.padding,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBackButton;
  final EdgeInsetsGeometry? padding;

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? ParentScreenHeaderLayout.padding,
      child: SizedBox(
        height: ParentScreenHeaderLayout.barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ParentScreenHeaderLayout.titleStyle,
              ),
            ),
            if (showBackButton)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: ParentScreenHeaderLayout.backButtonSize,
                child: GestureDetector(
                  onTap: () => _handleBack(context),
                  behavior: HitTestBehavior.opaque,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SvgPicture.asset(
                      'assets/figma/exchange_back_arrow.svg',
                      width: ParentScreenHeaderLayout.backIconSize,
                      height: ParentScreenHeaderLayout.backIconSize,
                    ),
                  ),
                ),
              ),
            if (trailing != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
