import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/home/child_soft_ui.dart';

// Remove iOS bouncing scroll — use Android-style clamping everywhere.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Clan Capital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
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
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kBgCloud,
                    image: DecorationImage(
                      image: AssetImage('assets/figma/cloud_bg.png'),
                      fit: BoxFit.cover,
                      opacity: 0.45,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
    );
  }
}

