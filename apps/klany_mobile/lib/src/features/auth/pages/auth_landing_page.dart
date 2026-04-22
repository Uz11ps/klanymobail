import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../home/child_soft_ui.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClanAuthScaffold(
      title: 'Добро пожаловать в Клан.',
      subtitle:
          'Выполняй задачи на Бирже, зарабатывай монеты и копи на свои мечты вместе с родителями.',
      children: [
        if (!Env.hasApiConfig) ...[
          ChildSoftCard(
            color: const Color(0xFFFFF4D6),
            borderColor: const Color(0xFFFFD88B),
            padding: const EdgeInsets.all(14),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB5761A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Демо-режим: заполните API_BASE_URL в apps/klany_mobile/.env',
                    style: TextStyle(
                      color: Color(0xFF6A4A10),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        ClanActionCard(
          title: 'У меня уже есть клан',
          subtitle: 'Войти как Глава Клана, родитель или ребёнок',
          icon: Icons.login,
          onTap: () => context.go('/auth/sign-in/role'),
        ),
        const SizedBox(height: 12),
        ClanActionCard(
          title: 'Создать новый клан',
          subtitle: 'Регистрация Главы Клана или ребёнка',
          icon: Icons.group_add,
          onTap: () => context.go('/auth/sign-up/role'),
        ),
        const SizedBox(height: 12),
        ClanActionCard(
          title: 'Присоединиться по коду',
          subtitle: 'Вступить в существующий клан',
          icon: Icons.qr_code_2,
          accentColor: kChildAccentOrange,
          onTap: () => context.go('/auth/join?role=child'),
        ),
      ],
    );
  }
}
