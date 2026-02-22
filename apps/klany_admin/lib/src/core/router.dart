import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dashboard/pages/dashboard_page.dart';

final _routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen(adminSessionProvider, (previous, next) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(adminSessionProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: ref.watch(_routerRefreshProvider),
    redirect: (context, state) {
      final path = state.uri.path;
      final loggedIn = sessionAsync.asData?.value != null;
      final inLogin = path == '/login';

      if (!loggedIn) return inLogin ? null : '/login';
      if (loggedIn && inLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
});

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

