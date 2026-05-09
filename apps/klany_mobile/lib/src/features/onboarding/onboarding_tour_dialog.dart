import 'package:flutter/material.dart';

import '../home/child_soft_ui.dart';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
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
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final active = i == _stepIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF555555)
                        : const Color(0xFFCFCFCF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              'Шаг ${_stepIndex + 1} из $total',
              style: const TextStyle(
                fontSize: 12,
                color: kChildInkMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kChildInk,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: kChildInkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            // Nav row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavCircleBtn(
                  icon: isFirst ? Icons.logout : Icons.chevron_left,
                  exit: isFirst,
                  onTap: () {
                    if (isFirst) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _stepIndex -= 1);
                    }
                  },
                ),
                _NavCircleBtn(
                  icon: isLast ? Icons.logout : Icons.chevron_right,
                  exit: isLast,
                  onTap: () {
                    if (isLast) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _stepIndex += 1);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCircleBtn extends StatelessWidget {
  const _NavCircleBtn({
    required this.icon,
    required this.exit,
    required this.onTap,
  });
  final IconData icon;
  final bool exit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: exit
          ? const Color(0xFFFFE0E0)
          : const Color(0xFFE3ECF8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: exit ? const Color(0xFFD83A3A) : kChildBrandBlue,
          ),
        ),
      ),
    );
  }
}
