import 'package:flutter/material.dart';

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
    barrierDismissible: false,
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
    final isLast = _stepIndex == total - 1;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Шаг ${_stepIndex + 1} из $total'),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(step.description),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Пропустить'),
        ),
        FilledButton(
          onPressed: () {
            if (isLast) {
              Navigator.of(context).pop();
              return;
            }
            setState(() => _stepIndex += 1);
          },
          child: Text(isLast ? 'Готово' : 'Далее'),
        ),
      ],
    );
  }
}
