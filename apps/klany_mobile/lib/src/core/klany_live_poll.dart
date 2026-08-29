import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'value_bump.dart';

/// Единый «пульс» приложения: раз в [kKlanyLivePollInterval] все подписанные
/// экраны тихо перезагружают данные с API.
class KlanyLiveTick extends Notifier<int> {
  Timer? _timer;
  _KlanyAppLifecycleObserver? _observer;

  @override
  int build() {
    _observer = _KlanyAppLifecycleObserver(
      onPause: () {
        _timer?.cancel();
        _timer = null;
      },
      onResume: () {
        state++;
        _ensureTimer();
      },
    );
    WidgetsBinding.instance.addObserver(_observer!);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(_observer!);
      _timer?.cancel();
    });
    _ensureTimer();
    return 0;
  }

  void _ensureTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(kKlanyLivePollInterval, (_) {
      state++;
    });
  }

  /// Сразу после мутации (создание квеста, заявка в магазине и т.д.).
  void bump() => state++;
}

class _KlanyAppLifecycleObserver with WidgetsBindingObserver {
  _KlanyAppLifecycleObserver({
    required this.onPause,
    required this.onResume,
  });

  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      onPause();
    } else if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

final klanyLiveTickProvider =
    NotifierProvider<KlanyLiveTick, int>(KlanyLiveTick.new);

void klanyLivePollBump(WidgetRef ref) {
  ref.read(klanyLiveTickProvider.notifier).bump();
}

/// Подписка на [klanyLiveTickProvider] для [ConsumerState].
mixin KlanyLivePollConsumerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  var _klanyLivePollHooked = false;

  @protected
  void onKlanyLivePoll({bool silent = true});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_klanyLivePollHooked) {
      _klanyLivePollHooked = true;
      ref.listenManual<int>(klanyLiveTickProvider, (previous, next) {
        if (previous != null && previous != next) {
          onKlanyLivePoll(silent: true);
        }
      });
    }
  }
}
