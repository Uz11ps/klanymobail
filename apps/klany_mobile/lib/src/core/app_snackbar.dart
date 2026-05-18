import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/child_soft_ui.dart';

/// Текущий path маршрута (корневой GoRouter), безопасно если виджет не под роутером.
String _currentGoRoutePath(BuildContext context) {
  final go = GoRouter.maybeOf(context);
  if (go == null) return '';
  try {
    return go.routerDelegate.currentConfiguration.uri.path;
  } catch (_) {
    return '';
  }
}

/// Отступ от **низа экрана** до нижней границы плавающего SnackBar.
/// На `/child` и `/parent` — выше фирменной капсулы навигации; на `/auth/*` —
/// только safe area + воздух.
double snackBarFloatingBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  final bottomSafe = math.max(mq.viewPadding.bottom, mq.padding.bottom);
  final path = _currentGoRoutePath(context);
  if (path.startsWith('/child')) {
    return ChildBottomClanBar.scrollBottomClearance(context) + 10;
  }
  if (path.startsWith('/parent')) {
    // Как высота слота `_ParentBottomBar`: капсула + паддинг снизу.
    const capsuleH = 76.0;
    const capsuleBottomPad = 16.0;
    return capsuleH + capsuleBottomPad + bottomSafe + 10;
  }
  return bottomSafe + 16;
}

SnackBar _decorateKlanySnackBar(BuildContext context, SnackBar s) {
  final bottom = snackBarFloatingBottomInset(context);
  return SnackBar(
    content: s.content,
    action: s.action,
    backgroundColor: s.backgroundColor,
    duration: s.duration,
    animation: s.animation,
    elevation: s.elevation ?? 10,
    clipBehavior: s.clipBehavior,
    padding: s.padding,
    width: s.width,
    shape: s.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    behavior: SnackBarBehavior.floating,
    dismissDirection: s.dismissDirection,
    showCloseIcon: s.showCloseIcon,
    closeIconColor: s.closeIconColor,
    hitTestBehavior: s.hitTestBehavior,
    margin: EdgeInsets.fromLTRB(14, 0, 14, bottom),
  );
}

extension KlanySnackBarOnContext on BuildContext {
  /// Показывает SnackBar **поверх контента**, **над нижней навигацией** (если она есть).
  /// Сбрасывает очередь — новое сообщение не «встаёт» третьим после двух минут показов.
  void showKlanySnackBar(SnackBar snackBar) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(_decorateKlanySnackBar(this, snackBar));
  }
}
