import 'package:flutter/material.dart';

/// Интервал тихого обновления агрегированных данных (дашборд, экран уведомлений,
/// блок «Экономика» родителя, экраны ребёнка). Не ниже разумной нагрузки на API.
const Duration kParentLivePollInterval = Duration(seconds: 14);

/// То же для экранов ребёнка (дашборд, задачи, магазин, кошелёк).
const Duration kChildLivePollInterval = kParentLivePollInterval;

/// Короткая анимация масштаба при смене [changeKey] (например, баланса или счётчика).
class ValueBumpWrap extends StatefulWidget {
  const ValueBumpWrap({
    super.key,
    required this.changeKey,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.beginScale = 1.08,
    this.alignment = Alignment.center,
  });

  /// Обычно число или хэш набора строк; виджет анимируется только когда ключ меняется.
  final Object changeKey;
  final Widget child;
  final Duration duration;
  /// Пик масштаба (лёгкое «дёрганье» без драматичного Zoom).
  final double beginScale;
  final AlignmentGeometry alignment;

  @override
  State<ValueBumpWrap> createState() => _ValueBumpWrapState();
}

class _ValueBumpWrapState extends State<ValueBumpWrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  Object? _lastKey;

  @override
  void initState() {
    super.initState();
    _lastKey = widget.changeKey;
    _c = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpIfStale());
  }

  /// После восстановления из жизненного цикла не дрожим на первом кадре.
  void _jumpIfStale() {
    if (!mounted) return;
    if (widget.changeKey != _lastKey) {
      _lastKey = widget.changeKey;
      _c.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant ValueBumpWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _c.duration = widget.duration;
    }
    if (widget.changeKey != oldWidget.changeKey &&
        widget.changeKey != _lastKey) {
      _lastKey = widget.changeKey;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(alignment: widget.alignment, scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}
