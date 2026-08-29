import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/klany_keyboard.dart';
import 'core/klany_live_poll.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/auth/auth_actions.dart';
import 'features/home/child_soft_ui.dart';

// Remove iOS bouncing scroll — use Android-style clamping everywhere.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ApiClient.onUnauthorized = () async {
        await ref.read(authActionsProvider).signOut();
        ref.read(routerProvider).go('/auth');
      };
    });
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    ref.watch(klanyLiveTickProvider);

    return MaterialApp.router(
      title: 'Clan Capital',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        // Force consistent status bar style on both platforms.
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
        // Prevent iOS from scaling text with system font size setting.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kBgCloud,
                    image: DecorationImage(
                    image: AssetImage('assets/figma/cloud_bg.png'),
                    fit: BoxFit.cover,
                    opacity: 0.22,
                    ),
                  ),
                ),
              ),
              if (child != null)
                Positioned.fill(
                  child: KlanyKeyboardFocusScroller(
                    child: klanyDismissKeyboardOnTap(child: child),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
