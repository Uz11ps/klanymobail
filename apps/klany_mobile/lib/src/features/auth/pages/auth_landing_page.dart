import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!Env.hasSupabaseConfig)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Демо-режим: заполните SUPABASE_URL и SUPABASE_ANON_KEY в apps/klany_mobile/.env',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            if (!Env.hasSupabaseConfig) const SizedBox(height: 16),
            _RoleCard(
              title: 'Я родитель',
              subtitle: 'Email + пароль, управление семьёй и квестами',
              icon: Icons.admin_panel_settings,
              onTap: () => context.go('/auth/parent/sign-in'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Я ребёнок',
              subtitle: 'Телефон + пароль, выполнение заданий и награды',
              icon: Icons.emoji_events,
              onTap: () => context.go('/auth/child/sign-in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

