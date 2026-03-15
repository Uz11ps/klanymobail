import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignInRoleChoicePage extends StatelessWidget {
  const SignInRoleChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActionCard(
                title: 'Вход администратора',
                subtitle: 'Вход по email или телефону',
                icon: Icons.admin_panel_settings,
                onTap: () => context.go('/auth/admin/sign-in'),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Вход пользователя',
                subtitle: 'Родитель: email/телефон + пароль',
                icon: Icons.person,
                onTap: () => context.go('/auth/parent/sign-in'),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Вход ребёнка',
                subtitle: 'Быстрый вход на этом устройстве',
                icon: Icons.child_care,
                onTap: () => context.go('/auth/child/sign-in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
              Icon(icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
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
