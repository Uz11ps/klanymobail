import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../home/child_soft_ui.dart';

/// Макет Figma «Мини-тур» (карточка ~0-1766): скругления, индикатор, кнопки, SVG.
const _kTourCardRadius = 54.0;
const _kTourPink = Color(0xFFFFD9D9);
const _kTourBlue = Color(0xFFEFF6FF);
const _kTourNavBtnRadius = 41.0;
const List<BoxShadow> _kTourNavBtnShadow = [
  BoxShadow(
    color: Color(0x0F000000),
    offset: Offset(0, 4),
    blurRadius: 2,
  ),
];

class TourStepData {
  const TourStepData({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

Future<void> showOnboardingTourDialog({
  required BuildContext context,
  required String title,
  required List<TourStepData> steps,
}) async {
  if (steps.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _OnboardingTourDialog(
      title: title,
      steps: steps,
    ),
  );
}

class _OnboardingTourDialog extends StatefulWidget {
  const _OnboardingTourDialog({
    required this.title,
    required this.steps,
  });

  /// Заголовок тура (на будущее / аналитика); на карточке показываются только шаги.
  final String title;
  final List<TourStepData> steps;

  @override
  State<_OnboardingTourDialog> createState() => _OnboardingTourDialogState();
}

class _OnboardingTourDialogState extends State<_OnboardingTourDialog> {
  int _stepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_stepIndex];
    final total = widget.steps.length;
    final isFirst = _stepIndex == 0;
    final isLast = _stepIndex == total - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kTourCardRadius),
            boxShadow: [
              ..._kTourNavBtnShadow,
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: i == _stepIndex ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _stepIndex
                            ? const Color(0xFF9C9C9C)
                            : const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Шаг ${_stepIndex + 1} из $total',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9C9C9C),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: kChildInkMuted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TourNavButton(
                    background: _kTourPink,
                    onTap: () {
                      if (isFirst) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _stepIndex -= 1);
                      }
                    },
                    child: isFirst
                        ? SvgPicture.asset(
                            'assets/figma/onboarding_sign_out.svg',
                            width: 24,
                            height: 24,
                          )
                        : Transform.rotate(
                            angle: math.pi,
                            child: SvgPicture.asset(
                              'assets/figma/onboarding_chevron_right.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                  ),
                  _TourNavButton(
                    background: _kTourBlue,
                    onTap: () {
                      if (isLast) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _stepIndex += 1);
                      }
                    },
                    child: isLast
                        ? SvgPicture.asset(
                            'assets/figma/onboarding_sign_out.svg',
                            width: 24,
                            height: 24,
                          )
                        : SvgPicture.asset(
                            'assets/figma/onboarding_chevron_right.svg',
                            width: 24,
                            height: 24,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourNavButton extends StatelessWidget {
  const _TourNavButton({
    required this.background,
    required this.onTap,
    required this.child,
  });

  final Color background;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kTourNavBtnRadius),
        boxShadow: _kTourNavBtnShadow,
      ),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kTourNavBtnRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
