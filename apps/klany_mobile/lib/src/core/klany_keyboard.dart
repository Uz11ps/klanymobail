import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Скрыть клавиатуру (один тап по пустой области / вне поля).
void klanyDismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Тап — закрыть клавиатуру; скролл — только скролл ([klanyKeyboardDismissManual]).
Widget klanyDismissKeyboardOnTap({required Widget child}) {
  return GestureDetector(
    onTap: klanyDismissKeyboard,
    behavior: HitTestBehavior.translucent,
    child: child,
  );
}

/// Прокрутить активное поле ввода в верхнюю треть видимой области (над клавиатурой).
///
/// При [Scaffold.resizeToAvoidBottomInset: false] страница сама не сдвигается —
/// без этого пользователь не видит, что можно проскроллить.
void klanyEnsureFocusedFieldVisible({
  double alignment = 0.18,
  Duration duration = const Duration(milliseconds: 280),
}) {
  final focus = FocusManager.instance.primaryFocus;
  final ctx = focus?.context;
  if (ctx == null || !ctx.mounted) return;
  final editableCtx = _findEditableTextContext(ctx);
  if (editableCtx == null) return;
  Scrollable.ensureVisible(
    editableCtx,
    alignment: alignment.clamp(0.0, 1.0),
    duration: duration,
    curve: Curves.easeOutCubic,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}

BuildContext? _findEditableTextContext(BuildContext from) {
  if (from.widget is EditableText) return from;
  final state = from.findAncestorStateOfType<EditableTextState>();
  if (state != null) return state.context;
  BuildContext? found;
  void visit(Element el) {
    if (found != null) return;
    if (el.widget is EditableText) {
      found = el;
      return;
    }
    el.visitChildren(visit);
  }

  if (from is Element) {
    from.visitChildren(visit);
  } else {
    from.visitChildElements(visit);
  }
  return found;
}

/// Глобально: при фокусе в поле + открытии клавиатуры — автосдвиг поля вверх.
class KlanyKeyboardFocusScroller extends StatefulWidget {
  const KlanyKeyboardFocusScroller({super.key, required this.child});

  final Widget child;

  @override
  State<KlanyKeyboardFocusScroller> createState() =>
      _KlanyKeyboardFocusScrollerState();
}

class _KlanyKeyboardFocusScrollerState extends State<KlanyKeyboardFocusScroller>
    with WidgetsBindingObserver {
  double _lastInset = 0;
  FocusNode? _lastFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    if (identical(focus, _lastFocus)) return;
    _lastFocus = focus;
    _scheduleEnsureVisible(frames: 2);
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final wasClosed = _lastInset <= klanyKeyboardOpenThreshold;
    final rising = inset > _lastInset + 8;
    final nowOpen = inset > klanyKeyboardOpenThreshold;
    _lastInset = inset;
    if ((wasClosed && nowOpen) || (nowOpen && rising)) {
      _scheduleEnsureVisible(frames: 3);
    }
  }

  void _scheduleEnsureVisible({required int frames}) {
    void tick(int left) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (left > 0) {
          tick(left - 1);
          return;
        }
        Future<void>.delayed(const Duration(milliseconds: 60), () {
          if (!mounted) return;
          klanyEnsureFocusedFieldVisible();
        });
      });
    }

    tick(frames);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Не скрывать клавиатуру при скролле — только по явному dismiss / тапу.
const klanyKeyboardDismissManual = ScrollViewKeyboardDismissBehavior.manual;

const klanyKeyboardDismissOnDrag = ScrollViewKeyboardDismissBehavior.onDrag;

const double klanyKeyboardOpenThreshold = 12;

/// Доп. отступ снизу при открытой клавиатуре — только когда клавиатура открыта.
const double klanyKeyboardScrollExtra = 16;

bool klanyKeyboardOpen(BuildContext context) =>
    klanyKeyboardScrollPadding(context) > klanyKeyboardOpenThreshold;

/// Высота клавиатуры — для нижнего padding прокручиваемого контента.
/// При [Scaffold.resizeToAvoidBottomInset: false] клавиатура ложится поверх UI.
double klanyKeyboardScrollPadding(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom;

/// Нижний padding скролла на страницах и в модалках.
double klanyScrollBottomPadding(BuildContext context, {double extra = 0}) {
  final keyboard = klanyKeyboardScrollPadding(context);
  if (keyboard <= klanyKeyboardOpenThreshold) return extra;
  return extra + keyboard + klanyKeyboardScrollExtra;
}

/// Нижний отступ ListView на обычных страницах (навбар + клавиатура).
double klanyPageScrollBottomPadding(BuildContext context, {double extra = 0}) =>
    klanyScrollBottomPadding(context, extra: extra);

EdgeInsets klanyCenterDialogInsets(
  BuildContext context, {
  double widthFraction = 0.8,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final side = math.max(0.0, (w * (1.0 - widthFraction)) / 2.0);
  return EdgeInsets.fromLTRB(side, 0, side, 0);
}

double klanyCenterDialogWidth(
  BuildContext context, {
  double widthFraction = 0.8,
}) =>
    MediaQuery.sizeOf(context).width * widthFraction;

/// Скролл модалки: только когда контент не помещается, без «пустого» тянущегося хода.
const ScrollPhysics klanyModalScrollPhysics = ClampingScrollPhysics();

/// Контент модалки: высота по содержимому; скролл включается только при переполнении.
class _KlanyAdaptiveModalScroll extends StatefulWidget {
  const _KlanyAdaptiveModalScroll({
    required this.maxHeight,
    required this.padding,
    required this.child,
  });

  final double maxHeight;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<_KlanyAdaptiveModalScroll> createState() =>
      _KlanyAdaptiveModalScrollState();
}

class _KlanyAdaptiveModalScrollState extends State<_KlanyAdaptiveModalScroll> {
  final GlobalKey _measureKey = GlobalKey();
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  @override
  void didUpdateWidget(covariant _KlanyAdaptiveModalScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  void _remeasure() {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final needs = box.size.height > widget.maxHeight + 0.5;
    if (needs != _needsScroll) {
      setState(() => _needsScroll = needs);
    }
  }

  Widget _paddedChild() {
    return Padding(
      key: _measureKey,
      padding: widget.padding,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _paddedChild();
    if (!_needsScroll) {
      return content;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        primary: false,
        physics: klanyModalScrollPhysics,
        keyboardDismissBehavior: klanyKeyboardDismissManual,
        child: content,
      ),
    );
  }
}

/// Тело центральной модалки: высота = контент, max-height + скролл при переполнении.
///
/// Клавиатуру учитываем уменьшением [maxHeight], а не нижним padding внутри скролла:
/// [Dialog] уже сдвигает окно через [MediaQuery.viewInsets] (AnimatedPadding).
/// Если клавиатуру ещё и добавить в padding контента — появляется «пустой» скролл вниз.
Widget klanyCenterDialogBody({
  required BuildContext context,
  required Widget child,
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
  double maxHeightFraction = 0.85,
}) {
  final size = MediaQuery.sizeOf(context);
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  // Вертикальные insetPadding у Dialog по умолчанию ≈ 24*2.
  const dialogVerticalChrome = 48.0;
  final maxByFraction = size.height * maxHeightFraction;
  final maxAboveKeyboard = size.height - keyboard - dialogVerticalChrome;
  final maxH = math.max(140.0, math.min(maxByFraction, maxAboveKeyboard));
  return klanyDismissKeyboardOnTap(
    child: _KlanyAdaptiveModalScroll(
      maxHeight: maxH,
      padding: contentPadding.copyWith(
        bottom: contentPadding.bottom +
            (keyboard > klanyKeyboardOpenThreshold ? klanyKeyboardScrollExtra : 0),
      ),
      child: child,
    ),
  );
}

/// Центральная Figma-модалка со скроллом при клавиатуре.
Future<T?> showKlanyFigmaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double widthFraction = 0.8,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final modalW = klanyCenterDialogWidth(ctx, widthFraction: widthFraction);
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding:
            klanyCenterDialogInsets(ctx, widthFraction: widthFraction),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: modalW,
          child: klanyCenterDialogBody(
            context: ctx,
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}

/// Padding снизу для скролла внутри bottom sheet (учитывает [klanyBottomSheetHost]).
double klanySheetKeyboardPadding(BuildContext context) =>
    _KlanySheetKeyboardScope.maybeOf(context) ??
    klanyKeyboardScrollPadding(context);

double klanySheetScrollBottomPadding(BuildContext context, {double extra = 0}) {
  final keyboard = klanySheetKeyboardPadding(context);
  if (keyboard <= klanyKeyboardOpenThreshold) return extra;
  return extra + keyboard + klanyKeyboardScrollExtra;
}

class _KlanySheetKeyboardScope extends InheritedWidget {
  const _KlanySheetKeyboardScope({
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_KlanySheetKeyboardScope>()
        ?.bottom;
  }

  @override
  bool updateShouldNotify(_KlanySheetKeyboardScope oldWidget) =>
      bottom != oldWidget.bottom;
}

/// Обёртка без сдвига sheet: сохраняет высоту клавиатуры для дочернего скролла.
Widget klanyBottomSheetKeyboardScope({
  required BuildContext context,
  required Widget child,
}) {
  final keyboard = klanyKeyboardScrollPadding(context);
  return _KlanySheetKeyboardScope(
    bottom: keyboard,
    child: MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: klanyDismissKeyboardOnTap(child: child),
    ),
  );
}

/// Bottom sheet: фикс. max-height, клавиатура поверх без сдвига панели.
Widget klanyBottomSheetHost({
  required BuildContext context,
  required Widget child,
  double maxHeightFraction = 0.92,
}) {
  final keyboard = klanyKeyboardScrollPadding(context);
  final maxH = MediaQuery.sizeOf(context).height * maxHeightFraction;
  return _KlanySheetKeyboardScope(
    bottom: keyboard,
    child: MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: klanyDismissKeyboardOnTap(child: child),
      ),
    ),
  );
}

/// Нижняя модалка: фиксированный max-height, без сдвига sheet при клавиатуре.
Widget klanyBottomSheetScrollBody({
  required BuildContext context,
  required Widget child,
  double? keyboardBottom,
}) {
  final keyboard = keyboardBottom ?? klanySheetScrollBottomPadding(context);
  final maxH = MediaQuery.sizeOf(context).height * 0.92;
  return klanyDismissKeyboardOnTap(
    child: _KlanyAdaptiveModalScroll(
      maxHeight: maxH,
      padding: EdgeInsets.only(bottom: keyboard),
      child: child,
    ),
  );
}
