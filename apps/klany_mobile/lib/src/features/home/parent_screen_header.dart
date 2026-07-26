import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Единая шапка родительских экранов: отступ сверху, «назад» слева, заголовок по центру.
abstract final class ParentScreenHeaderLayout {
  static const double barHeight = 48;
  static const double sideSlotWidth = 48;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(19, 16, 19, 12);

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
        child: Row(
          children: [
            SizedBox(
              width: ParentScreenHeaderLayout.sideSlotWidth,
              height: ParentScreenHeaderLayout.barHeight,
              child: showBackButton
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleBack(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/figma/exchange_back_arrow.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ParentScreenHeaderLayout.titleStyle,
              ),
            ),
            SizedBox(
              width: ParentScreenHeaderLayout.sideSlotWidth,
              height: ParentScreenHeaderLayout.barHeight,
              child: trailing != null
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
