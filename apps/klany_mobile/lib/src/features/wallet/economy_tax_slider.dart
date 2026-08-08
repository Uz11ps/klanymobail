import 'package:flutter/material.dart';

/// Сегментный регулятор глобального налога (0–50%, 8 сегментов).
class EconomyTaxSegmentSlider extends StatelessWidget {
  const EconomyTaxSegmentSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Доля налога: 0.0–0.5 (0–50%).
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const segments = 8;
    final active = ((value / 0.5) * segments).clamp(0, segments).round();
    return LayoutBuilder(
      builder: (context, constraints) {
        void apply(double dx) {
          final ratio = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onChanged((ratio * 0.5).clamp(0.0, 0.5));
        }

        return GestureDetector(
          onTapDown: (d) => apply(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => apply(d.localPosition.dx),
          child: Container(
            color: Colors.transparent,
            child: Row(
              children: List.generate(segments, (i) {
                final isActive = i < active;
                final isEdge = i == 0 || i == segments - 1;
                final color = isActive
                    ? const Color(0xFF7BC976)
                    : const Color(0xFFE89B9B);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isEdge ? 1 : 2),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.horizontal(
                          left: i == 0
                              ? const Radius.circular(11)
                              : Radius.zero,
                          right: i == segments - 1
                              ? const Radius.circular(11)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
