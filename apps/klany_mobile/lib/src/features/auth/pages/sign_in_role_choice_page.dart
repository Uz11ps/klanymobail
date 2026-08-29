import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';

class SignInRoleChoicePage extends StatelessWidget {
  const SignInRoleChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Вход в клан',
      subtitle: 'Выбери роль, под которой зайдёшь в клан.',
      children: [
        ClanActionCard(
          title: 'Вход администратора',
          subtitle: 'Вход по email или телефону',
          icon: Icons.admin_panel_settings,
          accentColor: kChildAccentOrange,
          onTap: () => context.go('/auth/admin/sign-in'),
        ),
        const SizedBox(height: 12),
        ClanActionCard(
          title: 'Вход пользователя',
          subtitle: 'Родитель: email/телефон + пароль',
          icon: Icons.person,
          onTap: () => context.go('/auth/parent/sign-in'),
        ),
        const SizedBox(height: 12),
        ClanActionCard(
          title: 'Вход ребёнка',
          subtitle: 'Быстрый вход на этом устройстве',
          icon: Icons.child_care,
          accentColor: kChildAccentGreen,
          onTap: () => context.go('/auth/child/sign-in'),
        ),
      ],
    );
  }
}
