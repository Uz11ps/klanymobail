import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.family_restroom, size: 44, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text('Klany', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const SizedBox(width: 160, child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

