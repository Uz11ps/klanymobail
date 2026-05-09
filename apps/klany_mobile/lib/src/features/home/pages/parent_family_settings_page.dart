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
import '../avatar_store.dart';
import '../child_soft_ui.dart';
import 'document_page.dart';
import 'tech_support_page.dart';

InputDecoration _settingsField(String hint, {Widget? prefixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kChildInkMuted, fontSize: 15),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    prefixIcon: prefixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
    ),
  );
}

class _SCard extends StatelessWidget {
  const _SCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      color: kChildSurfaceWhite,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Section title shown at the top of each settings card, with horizontal divider underneath.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kChildInk,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: kChildOutline),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class ParentFamilySettingsPage extends ConsumerStatefulWidget {
  const ParentFamilySettingsPage({super.key});

  @override
  ConsumerState<ParentFamilySettingsPage> createState() =>
      _ParentFamilySettingsPageState();
}

class _ParentFamilySettingsPageState
    extends ConsumerState<ParentFamilySettingsPage> {
  final _memberName = TextEditingController();
  final _inviteEmail = TextEditingController();
  final _promoCode = TextEditingController();
  final _goalName = TextEditingController();
  final _goalAmount = TextEditingController();
  String _memberRole = 'child';
  bool _busy = false;
  double _taxRate = 0.20;
  bool _pinEnabled = true;
  bool _parentalControl = true;

  @override
  void dispose() {
    _memberName.dispose();
    _inviteEmail.dispose();
    _promoCode.dispose();
    _goalName.dispose();
    _goalAmount.dispose();
    super.dispose();
  }

  // ─── Async actions ────────────────────────────────────────────────────────

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
      final code = await ref
          .read(parentAccessRepositoryProvider)
          .createFamilyMemberCode(memberType: _memberRole, displayName: name);
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
        const SnackBar(content: Text('Введите валидный email')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final token =
          await ref.read(parentAccessRepositoryProvider).createParentInvite(email);
      final text = 'Приглашение в клан. Family ID: ${family.familyCode}. '
          'Токен: $token';
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

  Future<void> _saveGoal() async {
    if (_busy) return;
    final parsed = int.tryParse(_goalAmount.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите сумму цели')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).setFamilyGoal(parsed);
      ref.invalidate(parentFamilyContextProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цель обновлена')),
      );
      _goalAmount.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activatePromo() async {
    if (_busy || _promoCode.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .activatePromo(_promoCode.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Промокод активирован')),
      );
      _promoCode.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка промокода: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyPremium() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final orderId = await ref
          .read(subscriptionRepositoryProvider)
          .createPaymentOrder(planCode: 'premium', amountRub: 499);
      final checkoutUrl = await ref
          .read(subscriptionRepositoryProvider)
          .createYookassaCheckoutUrl(orderId);
      if (!mounted) return;
      if ((checkoutUrl ?? '').isNotEmpty) {
        await launchUrlString(checkoutUrl!, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания платежа: $e')),
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
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
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
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteChild(String childId) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить ребёнка'),
        content: const Text('Ребёнок будет удалён из семьи. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD83A3A)),
            child: const Text('Удалить'),
          ),
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
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);

    return familyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Ошибка: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(body: Center(child: Text('Семья не найдена')));
        }
        return _buildPage(family);
      },
    );
  }

  Widget _buildPage(ParentFamilyContext family) {
    return FutureBuilder<
        (
          List<ParentMemberItem>,
          List<ChildMemberItem>,
          List<FamilyMemberCodeItem>
        )>(
      future: () async {
        final repo = ref.read(parentAccessRepositoryProvider);
        final parents = await repo.getParentMembers(family.familyId);
        final children = await repo.getChildren(family.familyId);
        final codes = await repo.getFamilyMemberCodes();
        return (parents, children, codes);
      }(),
      builder: (context, snapshot) {
        final parents =
            snapshot.data?.$1 ?? const <ParentMemberItem>[];
        final children =
            snapshot.data?.$2 ?? const <ChildMemberItem>[];
        final codes =
            snapshot.data?.$3 ?? const <FamilyMemberCodeItem>[];

        return Scaffold(
          backgroundColor: kBgCloud,
          appBar: AppBar(
            backgroundColor: kBgCloud,
            foregroundColor: kChildInk,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kChildInk),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            centerTitle: true,
            title: const Text(
              'CLAN CAPITAL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: kChildBrandBlue,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_outlined, color: kChildInk),
                onPressed:
                    _busy ? null : () => ref.read(authActionsProvider).signOut(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              // ── Page title ──────────────────────────────────────────────
              const Text(
                'НАСТРОЙКИ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: kChildInk,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Clan card (3 rows in one card) ───────────────────────────
              _SCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ClanRow(
                      avatarText: (family.clanName?.trim().isNotEmpty == true
                              ? family.clanName!
                              : 'К')
                          .characters
                          .first
                          .toUpperCase(),
                      title: family.clanName?.trim().isNotEmpty == true
                          ? family.clanName!
                          : 'Клан',
                      subtitle: 'Family ID: ${family.familyCode}',
                      subtitleColor: kChildBrandBlue,
                      userKey: 'parent:${family.familyId}',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: kChildOutline),
                    ),
                    _IconRow(
                      icon: Icons.badge_outlined,
                      title: 'Текущая учётная запись',
                      subtitle: 'Без имени\nГлава семьи',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: kChildOutline),
                    ),
                    _IconRow(
                      icon: Icons.school_outlined,
                      title: 'Показать обучение',
                      subtitle: 'Мини-тур по разделам',
                      onTap: _showTourAgain,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Family goal ──────────────────────────────────────────────
              _SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Общая цель семьи'),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'Название цели',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _goalName,
                      style: const TextStyle(fontSize: 15, color: kChildInk),
                      decoration: _settingsField('Купить велосипед'),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'Сумма цели',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _goalAmount,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15, color: kChildInk),
                      decoration: _settingsField(
                        family.goalAmount > 0
                            ? '${family.goalAmount}'
                            : 'Купить велосипед',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : _saveGoal,
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandMint,
                        foregroundColor: const Color(0xFF1F4F1B),
                        elevation: 4,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text(
                        'Сохранить цель',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Subscription ─────────────────────────────────────────────
              FutureBuilder<List<FamilySubscriptionItem>>(
                future: ref
                    .read(subscriptionRepositoryProvider)
                    .getFamilySubscriptions(family.familyId),
                builder: (context, subSnap) {
                  final subs = subSnap.data ?? const <FamilySubscriptionItem>[];
                  final current = subs.isNotEmpty ? subs.first : null;
                  final isPremium =
                      current?.planCode.toLowerCase().contains('premium') ==
                          true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'МОЙ ТАРИФ: ${isPremium ? "PREMIUM" : "BASIC"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kChildInkMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isPremium) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: kBrandLavender,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Мой тариф: PREMIUM',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: kChildInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                current?.expiresAt != null
                                    ? 'Активен до ${current!.expiresAt!.year}г.'
                                    : 'Активен',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: kChildInk,
                                ),
                              ),
                              const Text(
                                'Участников: 1/999',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: kChildInk,
                                ),
                              ),
                              const Text(
                                'Обратные и VIP задачи: доступны',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: kChildInk,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _busy ? null : _buyPremium,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: kChildInk,
                                  elevation: 4,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: const Text(
                                  'Управлять подпиской',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _busy ? null : _buyPremium,
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrandSky,
                            foregroundColor: kChildBrandBlue,
                            elevation: 4,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: const Text(
                            'УПРАВЛЯТЬ ПОДПИСКОЙ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Economics ────────────────────────────────────────
                      _SCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              'Экономика Клана',
                              trailing: GestureDetector(
                                onTap: () {},
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: kChildInk,
                                  size: 20,
                                ),
                              ),
                            ),
                            const Text(
                              'Курс монет: 10 монет = 100₽',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: kChildInk,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Глобальный налог:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: kChildInkMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_taxRate * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: kChildInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _TaxSegmentSlider(
                              value: _taxRate,
                              onChanged: (v) => setState(() => _taxRate = v),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: kChildOutline),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'PIN-код для Экономики',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kChildInk,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _pinEnabled,
                                  activeTrackColor: kBrandMint,
                                  activeThumbColor: Colors.white,
                                  inactiveTrackColor: kChildOutline,
                                  inactiveThumbColor: Colors.white,
                                  onChanged: (v) =>
                                      setState(() => _pinEnabled = v),
                                ),
                              ],
                            ),
                            const Divider(height: 1, color: kChildOutline),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Родительский контроль обратных задач',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kChildInk,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _parentalControl,
                                  activeTrackColor: kBrandMint,
                                  activeThumbColor: Colors.white,
                                  inactiveTrackColor: kChildOutline,
                                  inactiveThumbColor: Colors.white,
                                  onChanged: (v) =>
                                      setState(() => _parentalControl = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Promo / subscription card ─────────────────────────
                      _SCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionTitle(
                              'Подписка: ${current?.planCode ?? 'basic'}',
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 6, bottom: 6),
                              child: Text(
                                'Промокод',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kChildInk,
                                ),
                              ),
                            ),
                            TextField(
                              controller: _promoCode,
                              style: const TextStyle(
                                fontSize: 15,
                                color: kChildInk,
                              ),
                              decoration: _settingsField('промокод'),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: _busy ? null : _activatePromo,
                              style: FilledButton.styleFrom(
                                backgroundColor: kBrandMint,
                                foregroundColor: const Color(0xFF1F4F1B),
                                elevation: 4,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'Сохранить цель',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: _busy ? null : _buyPremium,
                              style: FilledButton.styleFrom(
                                backgroundColor: kBrandSky,
                                foregroundColor: kChildBrandBlue,
                                elevation: 4,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'Оплатить премиум',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Members ──────────────────────────────────────────────────
              _SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Участники клана'),
                    // Member tiles (square cards with avatar)
                    SizedBox(
                      height: 96,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: [
                          ...codes.take(8).map((c) {
                            final initial = c.displayName.isNotEmpty
                                ? c.displayName[0].toUpperCase()
                                : '?';
                            final asset = 'assets/figma/avatar_${(c.displayName.hashCode.abs() % 9) + 1}.png';
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _MemberTile(
                                avatarAsset: asset,
                                avatarFallback: initial,
                                label: c.displayName,
                              ),
                            );
                          }),
                          // Add button as square tile
                          Container(
                            width: 76,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE3ECF8),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.add,
                                color: kChildBrandBlue,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'Имя участника',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _memberName,
                      style:
                          const TextStyle(fontSize: 15, color: kChildInk),
                      decoration: _settingsField('Никита'),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'Роль',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: DropdownButton<String>(
                        value: _memberRole,
                        underline: const SizedBox(),
                        isExpanded: true,
                        hint: const Text(
                          'Ребёнок',
                          style: TextStyle(
                            fontSize: 15,
                            color: kChildInkMuted,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: kChildInk,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'child',
                            child: Text('Ребёнок'),
                          ),
                          DropdownMenuItem(
                            value: 'mom',
                            child: Text('Мама'),
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
                            : (v) {
                                if (v != null) {
                                  setState(() => _memberRole = v);
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : _createMemberCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandMint,
                        foregroundColor: const Color(0xFF1F4F1B),
                        elevation: 4,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text(
                        'Добавить участника',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (codes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...codes.take(12).map(
                            (item) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3ECF8),
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/figma/avatar_${(item.displayName.hashCode.abs() % 9) + 1}.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, e, s) => Text(
                                    item.displayName.isNotEmpty
                                        ? item.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: kChildBrandBlue,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.displayName} — ${item.code}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: kChildInk,
                                      ),
                                    ),
                                    Text(
                                      familyMemberTypeLabel(item.role),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: kChildInkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: kChildBrandBlue,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'Код входа для ${item.displayName}: ${item.code}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Second parent ────────────────────────────────────────────
              _SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Второй родитель'),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kChildInk,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _inviteEmail,
                      keyboardType: TextInputType.emailAddress,
                      style:
                          const TextStyle(fontSize: 15, color: kChildInk),
                      decoration: _settingsField(
                        'Email',
                        prefixIcon: const Icon(
                          Icons.alternate_email,
                          color: kChildBrandBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          _busy ? null : () => _inviteByEmail(family),
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandMint,
                        foregroundColor: const Color(0xFF1F4F1B),
                        elevation: 4,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text(
                        'Пригласить',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Support ──────────────────────────────────────────────────
              _SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Поддержка клана'),
                    _SkyButton(
                      label: 'Написать в поддержку',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TechSupportPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Legal ────────────────────────────────────────────────────
              _SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Юр. информация и Согласия'),
                    _SkyButton(
                      label: 'Пользовательское\nсоглашение',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DocumentPage(
                            title: 'Соглашение',
                            body: userAgreementBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SkyButton(
                      label: 'Политика\nконфиденциальности',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DocumentPage(
                            title: 'Политика',
                            body: privacyPolicyBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SkyButton(
                      label: 'Оферта о подписке\n(Premium)',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DocumentPage(
                            title: 'Оферта',
                            body: premiumOfferBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Управление данными'),
                    _SkyButton(
                      label: 'Согласие на обработку\nПД',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DocumentPage(
                            title: 'Согласие на ПД',
                            body: dataConsentBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Согласие на обработку\nПД: принято',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Switch(
                          value: true,
                          activeTrackColor: kBrandMint,
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: kChildOutline,
                          inactiveThumbColor: Colors.white,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Разрешить сбор\nстатистики',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Switch(
                          value: true,
                          activeTrackColor: kBrandMint,
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: kChildOutline,
                          inactiveThumbColor: Colors.white,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Analytics ────────────────────────────────────────────────
              FutureBuilder<Map<String, dynamic>>(
                future: ref
                    .read(parentAccessRepositoryProvider)
                    .getPremiumAnalytics(periodDays: 30),
                builder: (context, analyticsSnap) {
                  final data = analyticsSnap.data;
                  if (analyticsSnap.hasError ||
                      data == null ||
                      data.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      _SCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Premium-аналитика'),
                            Text(
                              'Дети: ${data['childrenCount'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: kChildInk,
                              ),
                            ),
                            Text(
                              'Квесты: ${data['questsCompleted'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: kChildInk,
                              ),
                            ),
                            Text(
                              'Транзакции: ${data['walletTxCount'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: kChildInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

              // ── Parents ──────────────────────────────────────────────────
              if (parents.isNotEmpty) ...[
                _SCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('Родители'),
                      ...parents.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.displayName.trim().isEmpty
                                          ? 'Без имени'
                                          : p.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: kChildInk,
                                      ),
                                    ),
                                    Text(
                                      p.role == 'admin'
                                          ? 'Глава семьи • Родитель'
                                          : 'Родитель',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kChildInkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.role == 'parent')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _grantAdmin(p.userId),
                                  child: const Text(
                                    'Сделать админом',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // OLD parents list (kept for compatibility)
              if (false) ...[
                const Text(
                  'Родители',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 8),
                ...parents.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                          p.displayName.trim().isEmpty
                              ? 'Без имени'
                              : p.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kChildInk,
                          ),
                        ),
                        subtitle: Text(
                          'Роль: ${p.role}',
                          style: const TextStyle(
                            color: kChildInkMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: p.role == 'parent'
                            ? TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _grantAdmin(p.userId),
                                child: const Text(
                                  'Сделать админом',
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                            : const Text(
                                'Админ',
                                style: TextStyle(
                                  color: kChildBrandBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Children ─────────────────────────────────────────────────
              if (children.isNotEmpty) ...[
                _SCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('Дети'),
                      ...children.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.displayName.trim().isEmpty
                                    ? 'Без имени'
                                    : c.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: kChildInk,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                c.isActive ? 'Активен' : 'Неактивен',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.isActive
                                      ? const Color(0xFF18B26B)
                                      : kChildInkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // OLD children list (kept for compatibility)
              if (false) ...[
                const Text(
                  'Дети',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 8),
                ...children.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.displayName.trim().isEmpty
                                ? 'Без имени'
                                : c.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kChildInk,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            c.isActive ? 'Активен' : 'Неактивен',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.isActive
                                  ? const Color(0xFF18B26B)
                                  : kChildInkMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _revokeChild(c.childId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kChildInkMuted,
                                    side: const BorderSide(
                                      color: kChildOutline,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Сброс устройств',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _deactivateChild(c.childId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kChildInkMuted,
                                    side: const BorderSide(
                                      color: kChildOutline,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Деактив.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteChild(c.childId),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFD83A3A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Удалить',
                                    style: TextStyle(fontSize: 11),
                                  ),
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
            ],
          ),
        );
      },
    );
  }
}

class _ClanRow extends StatefulWidget {
  const _ClanRow({
    required this.avatarText,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.userKey,
  });
  final String avatarText;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final String userKey;

  @override
  State<_ClanRow> createState() => _ClanRowState();
}

class _ClanRowState extends State<_ClanRow> {
  int _bumpKey = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final changed = await showAvatarPicker(
                context: context,
                userKey: widget.userKey,
                title: 'Выбрать аватар',
              );
              if (changed && mounted) setState(() => _bumpKey++);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  key: ValueKey(_bumpKey),
                  userKey: widget.userKey,
                  size: 48,
                  fallbackText: widget.avatarText,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kChildBrandBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3ECF8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: kChildInk, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kChildInkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxSegmentSlider extends StatelessWidget {
  const _TaxSegmentSlider({required this.value, required this.onChanged});
  final double value; // 0.0 - 0.5
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const segments = 8;
    // map value 0..0.5 to active count 0..8
    final active = ((value / 0.5) * segments).clamp(0, segments).round();
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) {
            final ratio = (d.localPosition.dx / constraints.maxWidth)
                .clamp(0.0, 1.0);
            onChanged((ratio * 0.5).clamp(0.0, 0.5));
          },
          onHorizontalDragUpdate: (d) {
            final ratio = (d.localPosition.dx / constraints.maxWidth)
                .clamp(0.0, 1.0);
            onChanged((ratio * 0.5).clamp(0.0, 0.5));
          },
          child: Container(
            color: Colors.transparent,
            child: Row(
              children: List.generate(segments, (i) {
                final isActive = i < active;
                final isEdge = i == 0 || i == segments - 1;
                final color = isActive
                    ? const Color(0xFF7BC976) // mint
                    : const Color(0xFFE89B9B); // pinkish-red
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isEdge ? 1 : 2),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.horizontal(
                          left: i == 0 ? const Radius.circular(11) : Radius.zero,
                          right: i == segments - 1
                              ? const Radius.circular(11)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.avatarAsset,
    required this.avatarFallback,
    required this.label,
  });
  final String avatarAsset;
  final String avatarFallback;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF2F8),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: Image.asset(
              avatarAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => Text(
                avatarFallback,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kChildBrandBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: kChildInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyButton extends StatelessWidget {
  const _SkyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kBrandSky,
          foregroundColor: kChildInk,
          elevation: 4,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
