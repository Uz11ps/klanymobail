import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Clan Capital')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!Env.hasApiConfig)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Демо-режим: заполните API_BASE_URL в apps/klany_mobile/.env',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            if (!Env.hasApiConfig) const SizedBox(height: 16),
            const Text(
              'Выберите роль для входа в семью по персональному коду.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/auth/join?role=parent'),
              child: const Text('Я родитель'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/auth/join?role=child'),
              child: const Text('Я ребёнок'),
            ),
          ],
        ),
      ),
    );
  }
}

