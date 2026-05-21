import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/app_role.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/child_session.dart';
import '../features/auth/parent_session.dart';
import '../features/auth/pages/auth_landing_page.dart';
import '../features/auth/pages/child_request_access_page.dart';
import '../features/auth/pages/child_sign_in_page.dart';
import '../features/auth/pages/child_wait_approval_page.dart';
import '../features/auth/pages/join_family_code_page.dart';
import '../features/auth/pages/parent_chief_register_page.dart';
import '../features/auth/pages/parent_sign_in_page.dart';
import '../features/auth/pages/parent_sign_up_page.dart';
import '../features/auth/pages/recover_access_page.dart';
import '../features/auth/pages/sign_in_role_choice_page.dart';
import '../features/auth/pages/sign_up_role_choice_page.dart';
import '../features/home/pages/child_home_page.dart';
import '../features/home/pages/parent_home_page.dart';
import '../features/splash/splash_page.dart';

final _routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  ref.listen(parentSessionProvider, (previous, next) => notifier.refresh());
  ref.listen(appRoleProvider, (previous, next) => notifier.refresh());
  ref.listen(childSessionProvider, (previous, next) => notifier.refresh());

  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: ref.watch(_routerRefreshProvider),
    redirect: (context, state) {
      final path = state.uri.path;
      final parentSessionAsync = ref.read(parentSessionProvider);
      final role = ref.read(appRoleProvider);
      final childSessionAsync = ref.read(childSessionProvider);

      final parentSession = parentSessionAsync.asData?.value;
      final childSession = childSessionAsync.asData?.value;

      // Fast path: if parent session already restored, never wait for child restore.
      if (parentSession != null && (role == AppRole.parent || role == null)) {
        final inAuth = path.startsWith('/auth');
        if (inAuth || path == '/' || path.isEmpty || path.startsWith('/child')) {
          return '/parent';
        }
        return null;
      }

      // Never keep user on splash while async providers are restoring.
      if ((parentSessionAsync.isLoading || childSessionAsync.isLoading) &&
          (path == '/' || path.isEmpty)) {
        return '/auth';
      }

      // Avoid redirect "flicker": wait until sessions are loaded from storage.
      if (parentSessionAsync.isLoading || childSessionAsync.isLoading) {
        return null;
      }

      final parentLoggedIn = parentSession != null &&
          (role == AppRole.parent || role == null);
      final childLoggedIn = childSession != null;
      final inAuth = path.startsWith('/auth');

      if (!parentLoggedIn && !childLoggedIn) {
        return inAuth ? null : '/auth';
      }

      // Logged in: keep auth screens inaccessible.
      if (inAuth) {
        if (parentLoggedIn) return '/parent';
        if (childLoggedIn) return '/child';
      }

      // Root always resolves to the correct home.
      if (path == '/' || path.isEmpty) {
        if (parentLoggedIn) return '/parent';
        if (childLoggedIn) return '/child';
      }

      if (parentLoggedIn && path.startsWith('/child')) return '/parent';
      if (childLoggedIn && path.startsWith('/parent')) return '/child';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      // Каждый экран — отдельная страница на корневом Navigator. Вложенные
      // GoRoute под /auth оставляли AuthLandingPage в стеке под sign-in
      // (просвечивали карусель и CTA — «лагающее» переключение).
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthLandingPage(),
      ),
      GoRoute(
        path: '/auth/join',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'child';
          return JoinFamilyCodePage(role: role);
        },
      ),
      GoRoute(
        path: '/auth/parent/sign-in',
        builder: (context, state) => const ParentSignInPage(),
      ),
      GoRoute(
        path: '/auth/admin/sign-in',
        builder: (context, state) => const ParentSignInPage(isAdmin: true),
      ),
      GoRoute(
        path: '/auth/parent/sign-up',
        builder: (context, state) => const ParentSignUpPage(),
      ),
      GoRoute(
        path: '/auth/parent/chief-register',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final email = extra is String
              ? extra
              : (state.uri.queryParameters['email'] ?? '');
          return MaterialPage<void>(
            key: state.pageKey,
            child: ParentChiefRegisterPage(initialEmail: email),
          );
        },
      ),
      GoRoute(
        path: '/auth/sign-in/role',
        builder: (context, state) => const SignInRoleChoicePage(),
      ),
      GoRoute(
        path: '/auth/child/sign-in',
        builder: (context, state) => const ChildSignInPage(),
      ),
      GoRoute(
        path: '/auth/sign-up/role',
        builder: (context, state) => const SignUpRoleChoicePage(),
      ),
      GoRoute(
        path: '/auth/recover',
        builder: (context, state) => const RecoverAccessPage(),
      ),
      GoRoute(
        path: '/auth/child/request',
        builder: (context, state) => const ChildRequestAccessPage(),
      ),
      GoRoute(
        path: '/auth/child/wait',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'] ?? '';
          return ChildWaitApprovalPage(requestId: requestId);
        },
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

