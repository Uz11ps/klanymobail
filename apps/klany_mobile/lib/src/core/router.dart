import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/app_role.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/pages/auth_landing_page.dart';
import '../features/auth/pages/child_sign_in_page.dart';
import '../features/auth/pages/parent_sign_in_page.dart';
import '../features/auth/pages/parent_sign_up_page.dart';
import '../features/home/pages/child_home_page.dart';
import '../features/home/pages/parent_home_page.dart';
import '../features/splash/splash_page.dart';

final _routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  ref.listen(authSessionProvider, (previous, next) => notifier.refresh());
  ref.listen(appRoleProvider, (previous, next) => notifier.refresh());

  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(authSessionProvider);
  final role = ref.watch(appRoleProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: ref.watch(_routerRefreshProvider),
    redirect: (context, state) {
      final path = state.uri.path;
      final loggedIn = sessionAsync.asData?.value != null;
      final inAuth = path.startsWith('/auth');

      if (!loggedIn) {
        return inAuth ? null : '/auth';
      }

      // Logged in: keep auth screens inaccessible.
      if (inAuth) {
        final targetRole = role ?? AppRole.parent;
        return targetRole == AppRole.parent ? '/parent' : '/child';
      }

      // Root always resolves to the correct home.
      if (path == '/' || path.isEmpty) {
        final targetRole = role ?? AppRole.parent;
        return targetRole == AppRole.parent ? '/parent' : '/child';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthLandingPage(),
        routes: [
          GoRoute(
            path: 'parent/sign-in',
            builder: (context, state) => const ParentSignInPage(),
          ),
          GoRoute(
            path: 'parent/sign-up',
            builder: (context, state) => const ParentSignUpPage(),
          ),
          GoRoute(
            path: 'child/sign-in',
            builder: (context, state) => const ChildSignInPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentHomePage(),
      ),
      GoRoute(
        path: '/child',
        builder: (context, state) => const ChildHomePage(),
      ),
    ],
  );
});

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

