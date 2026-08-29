import 'package:flutter/material.dart';

import '../../home/child_soft_ui.dart';

/// Общий стиль input-поля для всех экранов входа/регистрации.
InputDecoration authInputDecoration({
  String? hint,
  Widget? suffix,
  bool dense = false,
}) {
  const radius = 26.0;
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: kChildInkMuted,
      fontSize: 15,
    ),
    filled: true,
    fillColor: Colors.white,
    isDense: dense,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 16,
    ),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: Color(0xFFD83A3A), width: 1.4),
    ),
  );
}

/// Лейбл над полем ввода.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: kChildInk,
        ),
      ),
    );
  }
}

/// Большая primary-кнопка как CTA лендинга (мятный вертикальный градиент).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.fg,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? fg;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: kFigmaLandingCtaHeight,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF1F4F1B),
            ),
          ),
        ),
      );
    }
    if (color != null || fg != null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color ?? kBrandMint,
            foregroundColor: fg ?? const Color(0xFF000000),
          ),
          child: Text(
            label,
            style: fg != null
                ? kFigmaLandingCtaTextStyle.copyWith(color: fg)
                : null,
          ),
        ),
      );
    }
    return FigmaGradientButton(
      label: label,
      gradient: FigmaGradientButton.mintGradientVertical,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      onTap: onPressed,
    );
  }
}

/// Стандартный AppBar для экранов входа/регистрации.
PreferredSizeWidget authAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: kBgCloud,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: kChildInk),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    centerTitle: true,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: kChildInk,
      ),
    ),
  );
}
