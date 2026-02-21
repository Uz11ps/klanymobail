import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../auth/auth_actions.dart';
import '../../auth/parent_access_repository.dart';
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
  final _promoCode = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _inviteEmail.dispose();
    _promoCode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));

        return FutureBuilder<(List<ParentMemberItem>, List<ChildMemberItem>)>(
          future: () async {
            final repo = ref.read(parentAccessRepositoryProvider);
            final parents = await repo.getParentMembers(family.familyId);
            final children = await repo.getChildren(family.familyId);
            return (parents, children);
          }(),
          builder: (context, snapshot) {
            final parents = snapshot.data?.$1 ?? const <ParentMemberItem>[];
            final children = snapshot.data?.$2 ?? const <ChildMemberItem>[];

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

