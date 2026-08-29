import 'package:flutter/material.dart';

import 'klany_keyboard.dart';

/// Bottom sheet без подъёма контента при клавиатуре — только внутренний скролл.
Future<T?> showKlanyModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  double maxHeightFraction = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor ?? Colors.white,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
    builder: (ctx) => klanyBottomSheetHost(
      context: ctx,
      maxHeightFraction: maxHeightFraction,
      child: klanyBottomSheetScrollBody(
        context: ctx,
        child: builder(ctx),
      ),
    ),
  );
}

/// Bottom sheet с собственным ListView/скроллом внутри [builder].
Future<T?> showKlanyScrollableBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  double maxHeightFraction = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor ?? Colors.white,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
    builder: (ctx) => klanyBottomSheetHost(
      context: ctx,
      maxHeightFraction: maxHeightFraction,
      child: builder(ctx),
    ),
  );
}

/// Панель снизу (тур, редактирование профиля, аватар).
Future<T?> showKlanyBottomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  double maxHeightFraction = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.white,
    barrierColor: barrierColor ?? Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => klanyBottomSheetHost(
      context: ctx,
      maxHeightFraction: maxHeightFraction,
      child: klanyBottomSheetScrollBody(
        context: ctx,
        child: builder(ctx),
      ),
    ),
  );
}

/// Стандартная разметка bottom-панели: заголовок + блоки, без лишней высоты.
Widget klanyBottomSheetPanel({
  String? title,
  required List<Widget> children,
  EdgeInsets? padding,
}) {
  return Builder(
    builder: (context) {
      final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
      final resolved = padding ??
          EdgeInsets.fromLTRB(24, 12, 24, 12 + safeBottom);
      return Padding(
        padding: resolved,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      );
    },
  );
}
