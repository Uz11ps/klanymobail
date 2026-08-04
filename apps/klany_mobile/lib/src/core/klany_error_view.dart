import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_snackbar.dart';

/// Показать SnackBar и уйти назад ([onBack], go_router pop или Navigator pop).
void klanyFailAndGoBack(
  BuildContext context, {
  Object? error,
  VoidCallback? onBack,
}) {
  if (!context.mounted) return;
  context.showKlanyNetworkErrorSnackBar(error);
  if (onBack != null) {
    onBack();
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    context.pop();
    return;
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

/// При ошибке загрузки экрана: snackbar + назад.
class KlanyErrorGoBack extends StatefulWidget {
  const KlanyErrorGoBack({super.key, this.error, this.onBack});

  final Object? error;
  final VoidCallback? onBack;

  @override
  State<KlanyErrorGoBack> createState() => _KlanyErrorGoBackState();
}

class _KlanyErrorGoBackState extends State<KlanyErrorGoBack> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      klanyFailAndGoBack(
        context,
        error: widget.error,
        onBack: widget.onBack,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Понятный текст ошибки в списках (без стека).
class KlanyFriendlyErrorText extends StatelessWidget {
  const KlanyFriendlyErrorText(
    this.error, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  final Object? error;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      klanyBriefErrorMessage(error),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
