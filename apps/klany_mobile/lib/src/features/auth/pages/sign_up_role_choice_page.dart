import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../home/child_soft_ui.dart';

class SignUpRoleChoicePage extends StatelessWidget {
  const SignUpRoleChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      leading: const ClanBackButton(),
      title: 'Регистрация в клане',
      subtitle:
          'Выбери роль: Глава Клана создаёт семью, ребёнок запрашивает доступ.',
      children: [
        ClanActionCard(
          title: 'Регистрация пользователя',
          subtitle: 'Создать родительский аккаунт по телефону',
          icon: Icons.person_add,
          onTap: () => context.go('/auth/parent/sign-up'),
        ),
        const SizedBox(height: 12),
        ClanActionCard(
          title: 'Регистрация ребёнка',
          subtitle: 'Запросить доступ у родителя',
          icon: Icons.child_friendly,
          accentColor: kChildAccentGreen,
          onTap: () => context.go('/auth/child/request'),
        ),
      ],
    );
  }
}
