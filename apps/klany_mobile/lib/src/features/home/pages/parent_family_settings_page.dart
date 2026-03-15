import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../auth/auth_actions.dart';
import '../../auth/parent_access_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';
import '../../subscriptions/subscription_repository.dart';

class ParentFamilySettingsPage extends ConsumerStatefulWidget {
  const ParentFamilySettingsPage({super.key});

  @override
  ConsumerState<ParentFamilySettingsPage> createState() =>
      _ParentFamilySettingsPageState();
}

class _ParentFamilySettingsPageState
    extends ConsumerState<ParentFamilySettingsPage> {
  final _inviteEmail = TextEditingController();
  final _memberName = TextEditingController();
  final _promoCode = TextEditingController();
  final _goalAmount = TextEditingController();
  String _memberRole = 'mom';
  bool _busy = false;

  @override
  void dispose() {
    _inviteEmail.dispose();
    _memberName.dispose();
    _promoCode.dispose();
    _goalAmount.dispose();
    super.dispose();
  }

  Future<void> _createMemberCode() async {
    if (_busy) return;
    final name = _memberName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя участника')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await ref.read(parentAccessRepositoryProvider).createFamilyMemberCode(
            memberType: _memberRole,
            displayName: name,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Код для ${code.displayName}: ${code.code}')),
      );
      _memberName.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания кода: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inviteByEmail(ParentFamilyContext family) async {
    if (_busy) return;
    final email = _inviteEmail.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите валидный email для приглашения')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final token =
          await ref.read(parentAccessRepositoryProvider).createParentInvite(email);
      final text = 'Приглашение в клан. Family ID: ${family.familyCode}. '
          'Токен для входа второго родителя: $token';
      await SharePlus.instance.share(ShareParams(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Инвайт создан и отправлен')),
      );
      _inviteEmail.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка приглашения: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantAdmin(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).grantAdmin(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Админ-роль передана')),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка передачи роли: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeChild(String childId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).revokeChildDevices(childId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Устройства ребёнка отключены')),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отзыва доступа: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivateChild(String childId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).deactivateChild(childId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ребёнок деактивирован')),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка деактивации: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteChild(String childId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ребёнка'),
        content: const Text('Ребёнок будет удалён из семьи полностью. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).deleteChild(childId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ребёнок удалён')),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTourAgain() async {
    if (_busy) return;
    await showOnboardingTourDialog(
      context: context,
      title: parentTourTitle,
      steps: parentTourSteps,
    );
    await OnboardingStore.setParentTourSeen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Обучение показано повторно')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));

        return FutureBuilder<(List<ParentMemberItem>, List<ChildMemberItem>, List<FamilyMemberCodeItem>)>(
          future: () async {
            final repo = ref.read(parentAccessRepositoryProvider);
            final parents = await repo.getParentMembers(family.familyId);
            final children = await repo.getChildren(family.familyId);
            final codes = await repo.getFamilyMemberCodes();
            return (parents, children, codes);
          }(),
          builder: (context, snapshot) {
            final parents = snapshot.data?.$1 ?? const <ParentMemberItem>[];
            final children = snapshot.data?.$2 ?? const <ChildMemberItem>[];
            final codes = snapshot.data?.$3 ?? const <FamilyMemberCodeItem>[];

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('Семья и доступы'),
                  actions: [
                    IconButton(
                      tooltip: 'Выйти',
                      onPressed: _busy
                          ? null
                          : () => ref.read(authActionsProvider).signOut(),
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.family_restroom),
                            title: Text(family.clanName?.isNotEmpty == true
                                ? family.clanName!
                                : 'Клан'),
                            subtitle: Text('Family ID: ${family.familyCode}'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.school),
                            title: const Text('Показать обучение снова'),
                            subtitle: const Text('Повторно открыть мини-тур по разделам'),
                            onTap: _showTourAgain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Общая цель семьи',
                                    style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _goalAmount,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Цель в 🏠',
                                    hintText: family.goalAmount.toString(),
                                    prefixIcon: const Icon(Icons.flag),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                                  final messenger =
                                                      ScaffoldMessenger.of(context);
                                          final parsed =
                                              int.tryParse(_goalAmount.text.trim());
                                          if (parsed == null || parsed <= 0) return;
                                          setState(() => _busy = true);
                                          try {
                                            await ref
                                                .read(parentAccessRepositoryProvider)
                                                .setFamilyGoal(parsed);
                                            ref.invalidate(parentFamilyContextProvider);
                                            if (!mounted) return;
                                                    messenger.showSnackBar(
                                              const SnackBar(
                                                  content: Text('Цель обновлена')),
                                            );
                                            _goalAmount.clear();
                                          } catch (e) {
                                            if (!mounted) return;
                                                    messenger.showSnackBar(
                                              SnackBar(
                                                  content: Text('Ошибка обновления цели: $e')),
                                            );
                                          } finally {
                                            if (mounted) setState(() => _busy = false);
                                          }
                                        },
                                  child: const Text('Сохранить цель'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<FamilySubscriptionItem>>(
                          future: ref
                              .read(subscriptionRepositoryProvider)
                              .getFamilySubscriptions(family.familyId),
                          builder: (context, subscriptionSnap) {
                            final subscriptions =
                                subscriptionSnap.data ?? const <FamilySubscriptionItem>[];
                            final current = subscriptions.isNotEmpty
                                ? subscriptions.first
                                : null;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Подписка: ${current?.planCode ?? 'basic'} (${current?.status ?? 'active'})',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    if (current?.expiresAt != null)
                                      Text('До: ${current!.expiresAt!.toLocal()}'),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _promoCode,
                                      decoration: const InputDecoration(
                                        labelText: 'Промокод',
                                        prefixIcon: Icon(Icons.redeem),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.tonal(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    if (_promoCode.text.trim().isEmpty) return;
                                                    setState(() => _busy = true);
                                                    try {
                                                      await ref
                                                          .read(subscriptionRepositoryProvider)
                                                          .activatePromo(_promoCode.text);
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                                        const SnackBar(
                                                            content: Text('Промокод активирован')),
                                                      );
                                                      _promoCode.clear();
                                                      setState(() {});
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                                        SnackBar(
                                                            content: Text('Ошибка промокода: $e')),
                                                      );
                                                    } finally {
                                                      if (mounted) setState(() => _busy = false);
                                                    }
                                                  },
                                            child: const Text('Активировать'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    setState(() => _busy = true);
                                                    try {
                                                      final orderId = await ref
                                                          .read(subscriptionRepositoryProvider)
                                                          .createPaymentOrder(
                                                            planCode: 'premium',
                                                            amountRub: 499,
                                                          );
                                                      final checkoutUrl = await ref
                                                          .read(subscriptionRepositoryProvider)
                                                          .createYookassaCheckoutUrl(orderId);
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'Платёж создан: $orderId')),
                                                      );
                                                      if ((checkoutUrl ?? '').isNotEmpty) {
                                                        await launchUrlString(
                                                          checkoutUrl!,
                                                          mode: LaunchMode.externalApplication,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'Ошибка создания платежа: $e')),
                                                      );
                                                    } finally {
                                                      if (mounted) setState(() => _busy = false);
                                                    }
                                                  },
                                            child: const Text('Оплатить premium'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Коды доступа членов семьи',
                                    style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _memberName,
                                  decoration: const InputDecoration(
                                    labelText: 'Имя участника',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _memberRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Роль участника',
                                    prefixIcon: Icon(Icons.badge),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'mom',
                                      child: Text('Мама'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'child',
                                      child: Text('Ребёнок'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'grandma',
                                      child: Text('Бабушка'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'grandpa',
                                      child: Text('Дедушка'),
                                    ),
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() => _memberRole = value);
                                        },
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _busy ? null : _createMemberCode,
                                  icon: const Icon(Icons.password),
                                  label: const Text('Создать код доступа'),
                                ),
                                const SizedBox(height: 8),
                                ...codes.take(12).map(
                                  (item) => ListTile(
                                    dense: true,
                                    leading: Icon(
                                      item.role == 'child'
                                          ? Icons.child_care
                                          : Icons.family_restroom,
                                    ),
                                    title: Text('${item.displayName} — ${item.code}'),
                                    subtitle: Text(familyMemberTypeLabel(item.role)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _inviteEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email второго родителя',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _inviteByEmail(family),
                          icon: const Icon(Icons.share),
                          label: const Text('Пригласить второго родителя'),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, dynamic>>(
                          future: ref
                              .read(parentAccessRepositoryProvider)
                              .getPremiumAnalytics(periodDays: 30),
                          builder: (context, analyticsSnap) {
                            final data = analyticsSnap.data;
                            if (analyticsSnap.hasError) {
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Аналитика доступна на premium',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              );
                            }
                            if (data == null || data.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Premium аналитика',
                                        style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    Text('Дети: ${data['childrenCount'] ?? 0}'),
                                    Text('Квесты завершены: ${data['questsCompleted'] ?? 0}'),
                                    Text('Транзакции: ${data['walletTxCount'] ?? 0}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Родители', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...parents.map(
                          (p) => Card(
                            child: ListTile(
                              title: Text(p.displayName),
                              subtitle: Text('Роль: ${p.role}'),
                              trailing: p.role == 'parent'
                                  ? TextButton(
                                      onPressed: _busy ? null : () => _grantAdmin(p.userId),
                                      child: const Text('Сделать админом'),
                                    )
                                  : const Text('Админ'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Дети', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...children.map(
                          (c) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.displayName,
                                      style: Theme.of(context).textTheme.titleSmall),
                                  Text(c.isActive ? 'Активен' : 'Неактивен'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _revokeChild(c.childId),
                                          child: const Text('Выйти на всех устройствах'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.tonal(
                                          onPressed: _busy
                                              ? null
                                              : () => _deactivateChild(c.childId),
                                          child: const Text('Деактивировать'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _deleteChild(c.childId),
                                          child: const Text('Удалить'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

