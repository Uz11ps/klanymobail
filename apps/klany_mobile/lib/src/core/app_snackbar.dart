import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String userFriendlyErrorMessage(Object? error) {
  var raw = (error ?? '').toString().trim();
  if (raw.isEmpty) return 'Что-то пошло не так. Попробуйте ещё раз.';

  raw = raw
      .replaceFirst(
        RegExp(r'^(Exception|TimeoutException|FormatException):\s*'),
        '',
      )
      .replaceFirst(RegExp(r'^Ошибка\s*:\s*', caseSensitive: false), '')
      .replaceFirst(
        RegExp(r'^Не удалось войти\s*:\s*', caseSensitive: false),
        '',
      )
      .trim();

  final firstLine = raw.split('\n').first.trim();
  final lower = raw.toLowerCase();

  if (lower.contains('network_timeout') ||
      lower.contains('timed out') ||
      lower.contains('timeoutexception') ||
      lower.contains('timeout')) {
    return 'Сервер долго не отвечает. Проверьте интернет и попробуйте ещё раз.';
  }

  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('network error') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed to fetch') ||
      lower.contains('httpexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('certificate_verify_failed') ||
      lower.contains('os error') ||
      lower.contains('ошибка сети')) {
    return 'Не удалось подключиться. Проверьте интернет и попробуйте ещё раз.';
  }

  if (lower.contains('api не настроен') ||
      lower.contains('api not configured')) {
    return 'Сервис временно недоступен. Попробуйте позже.';
  }

  // Неверный пароль до эвристик «401 / unauthorized», иначе текст входа может стать «сессия истекла».
  if (lower.contains('invalid credentials') ||
      lower.contains('invalid login') ||
      (lower.contains('неверн') &&
          (lower.contains('парол') ||
              lower.contains('телефон') ||
              lower.contains('email/')))) {
    return 'Неверный email или пароль.';
  }

  if (lower.contains('user already exists') ||
      lower.contains('email already') ||
      lower.contains('already registered') ||
      lower.contains('пользователь уже существует')) {
    return 'Этот email уже зарегистрирован. Войдите или используйте другой.';
  }

  if (lower.contains('unauthorized') ||
      lower.contains('не авторизован') ||
      lower.contains('jwt') ||
      lower.contains('401')) {
    return 'Сессия истекла. Войдите ещё раз.';
  }

  if (lower.contains('forbidden') ||
      lower.contains('доступ запрещ') ||
      lower.contains('403')) {
    return 'У вас нет доступа к этому действию.';
  }

  if (lower.contains('not found') || lower.contains('404')) {
    return 'Не удалось найти нужные данные. Обновите экран и попробуйте ещё раз.';
  }

  if (lower.contains('insufficient') ||
      (lower.contains('недостаточно') &&
          (lower.contains('средств') || lower.contains('монет')))) {
    return 'Не хватает монет на этом счёте.';
  }

  if (lower.contains('validation') ||
      lower.contains('bad request') ||
      lower.contains('400')) {
    return 'Проверьте введённые данные.';
  }

  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('504') ||
      lower.contains('internal server error') ||
      lower.contains('bad gateway') ||
      lower.contains('service unavailable') ||
      lower.contains('cannot get') ||
      lower.contains('cannot post') ||
      lower.contains('cannot patch') ||
      lower.contains('cannot delete')) {
    return 'Сервер временно недоступен. Попробуйте позже.';
  }

  if (lower.contains('formatexception') ||
      lower.contains('unexpected character') ||
      lower.contains('unexpected token')) {
    return 'Сервер прислал некорректный ответ. Попробуйте позже.';
  }

  if (lower.contains('type ') ||
      lower.contains('nosuchmethoderror') ||
      lower.contains('stack trace') ||
      lower.contains('package:') ||
      lower.contains('dart:') ||
      RegExp(r'#\d+\s+').hasMatch(raw)) {
    return 'Что-то пошло не так. Попробуйте ещё раз.';
  }

  if (lower.contains('bucket') ||
      lower.contains('minio') ||
      lower.contains('загрузка файла')) {
    return 'Не удалось загрузить файл. Попробуйте ещё раз позже.';
  }

  if (lower.startsWith('ошибка промокода') ||
      lower.contains('invalid promo') ||
      lower.contains('promo')) {
    return 'Промокод не подошёл. Проверьте код и попробуйте ещё раз.';
  }

  if (lower.startsWith('ошибка создания платежа') ||
      lower.contains('payment')) {
    return 'Не удалось открыть оплату. Попробуйте ещё раз.';
  }

  if (lower.startsWith('ошибка создания кода')) {
    return 'Не удалось создать код. Попробуйте ещё раз.';
  }

  if (lower.startsWith('ошибка')) {
    return 'Не получилось выполнить действие. Попробуйте ещё раз.';
  }

  return firstLine.isEmpty
      ? 'Что-то пошло не так. Попробуйте ещё раз.'
      : firstLine;
}

Widget _sanitizeSnackBarContent(Widget content) {
  if (content is Text && content.data != null) {
    final text = content.data!;
    final friendly = userFriendlyErrorMessage(text);
    return Text(
      friendly,
      style: content.style,
      strutStyle: content.strutStyle,
      textAlign: content.textAlign,
      textDirection: content.textDirection,
      locale: content.locale,
      softWrap: content.softWrap,
      overflow: content.overflow,
      textScaler: content.textScaler,
      maxLines: content.maxLines,
      semanticsLabel: content.semanticsLabel,
      textWidthBasis: content.textWidthBasis,
      textHeightBehavior: content.textHeightBehavior,
      selectionColor: content.selectionColor,
    );
  }
  return content;
}

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

/// Нижний margin у плавающего SnackBar.
///
/// **Важно:** [Scaffold] сам ставит floating SnackBar так, что нижний край слота
/// совпадает с [contentBottom], то есть уже **над** [bottomNavigationBar].
/// Если сюда снова прибавить высоту капсулы ([ChildBottomClanBar] и т.п.), получается
/// двойной учёт — SnackBar уезжает сильно вверх («посередине экрана»).
/// Здесь задаём только небольшой зазор над слотом навигации (+ системный низ там,
/// где Scaffold сам не поднимает якорь — экраны без нижней панели).
double snackBarFloatingBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  final bottomSafe = math.max(mq.viewPadding.bottom, mq.padding.bottom);
  final path = _currentGoRoutePath(context);
  if (path.startsWith('/child') || path.startsWith('/parent')) {
    const gapAboveBottomNavSlot = 14.0;
    return gapAboveBottomNavSlot;
  }
  return bottomSafe + 16;
}

SnackBar _decorateKlanySnackBar(BuildContext context, SnackBar s) {
  final bottom = snackBarFloatingBottomInset(context);
  return SnackBar(
    content: _sanitizeSnackBarContent(s.content),
    action: s.action,
    backgroundColor: s.backgroundColor,
    duration: s.duration,
    animation: s.animation,
    elevation: s.elevation ?? 10,
    clipBehavior: s.clipBehavior,
    padding: s.padding,
    width: s.width,
    shape:
        s.shape ??
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
  /// Показывает SnackBar у нижнего края контента; на `/child` и `/parent`
  /// [Scaffold] уже держит слот над нижней навигацией — добавляется только небольшой зазор.
  /// Сбрасывает очередь — новое сообщение не «встаёт» третьим после двух минут показов.
  void showKlanySnackBar(SnackBar snackBar) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(_decorateKlanySnackBar(this, snackBar));
  }
}
