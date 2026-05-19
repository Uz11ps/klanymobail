import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_actions.dart';
import '../../auth/parent_access_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../subscriptions/subscription_repository.dart';
import '../../subscriptions/pages/subscription_plans_page.dart';
import '../avatar_store.dart';
import '../child_soft_ui.dart';
import 'document_page.dart';
import 'tech_support_page.dart';
import '../../../core/app_snackbar.dart';

const Color _figmaSettingsMint = Color(0xFFD9F6C2);
const Color _figmaSettingsSkyButton = Color(0xFF9EC4F6);
const Color _figmaSettingsLavender = Color(0xFFD8CBF7);
const Color _figmaSettingsFieldBorder = Color(0x14000000);

double _settingsPageWidth(double screenWidth) {
  if (screenWidth < 430) return math.max(0, screenWidth);
  if (screenWidth < 700) return math.min(screenWidth - 32, 430);
  return math.min(screenWidth * 0.72, 640);
}

ButtonStyle _figmaSettingsButtonStyle({
  required Color backgroundColor,
  Color foregroundColor = Colors.black,
}) {
  return FilledButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    elevation: 4,
    minimumSize: const Size.fromHeight(56),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(62)),
    textStyle: const TextStyle(
      fontFamily: 'Nunito',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
  );
}

InputDecoration _settingsField(String hint, {Widget? prefixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Colors.black.withValues(alpha: 0.10),
      fontFamily: 'Nunito',
      fontSize: 20,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    constraints: const BoxConstraints(minHeight: 56),
    prefixIcon: prefixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(62),
      borderSide: const BorderSide(color: _figmaSettingsFieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(62),
      borderSide: const BorderSide(color: _figmaSettingsFieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(62),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.04),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(10, 30, 10, 30),
        child: child,
      ),
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
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.12)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ParentPremiumAnalyticsSection extends ConsumerStatefulWidget {
  const _ParentPremiumAnalyticsSection();

  @override
  ConsumerState<_ParentPremiumAnalyticsSection> createState() =>
      _ParentPremiumAnalyticsSectionState();
}

class _ParentPremiumAnalyticsSectionState
    extends ConsumerState<_ParentPremiumAnalyticsSection> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(parentAccessRepositoryProvider)
        .getPremiumAnalytics(periodDays: 30);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, analyticsSnap) {
        final data = analyticsSnap.data;
        if (analyticsSnap.hasError || data == null || data.isEmpty) {
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
                    style: const TextStyle(fontSize: 14, color: kChildInk),
                  ),
                  Text(
                    'Квесты: ${data['questsCompleted'] ?? 0}',
                    style: const TextStyle(fontSize: 14, color: kChildInk),
                  ),
                  Text(
                    'Транзакции: ${data['walletTxCount'] ?? 0}',
                    style: const TextStyle(fontSize: 14, color: kChildInk),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
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
      context.showKlanySnackBar(
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
      context.showKlanySnackBar(
        SnackBar(content: Text('Код для ${code.displayName}: ${code.code}')),
      );
      _memberName.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
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
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите валидный email')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final token = await ref
          .read(parentAccessRepositoryProvider)
          .createParentInvite(email);
      final text =
          'Приглашение в клан. Family ID: ${family.familyCode}. '
          'Токен: $token';
      await SharePlus.instance.share(ShareParams(text: text));
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Инвайт создан и отправлен')),
      );
      _inviteEmail.clear();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
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
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите сумму цели')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).setFamilyGoal(parsed);
      ref.invalidate(parentFamilyContextProvider);
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Цель обновлена')),
      );
      _goalAmount.clear();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
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
      context.showKlanySnackBar(
        const SnackBar(content: Text('Промокод активирован')),
      );
      _promoCode.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка промокода: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyPremium() async {
    if (_busy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionPlansPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editMemberAvatar(
    String familyId,
    FamilyMemberCodeItem code,
  ) async {
    if (_busy) return;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Готовый аватар'),
              onTap: () => Navigator.pop(ctx, 'preset'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || pick == null) return;

    if (pick == 'gallery') {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (img == null || !mounted) return;
      setState(() => _busy = true);
      try {
        await ref
            .read(parentAccessRepositoryProvider)
            .uploadMemberCodeAvatar(
              familyId: familyId,
              memberCodeId: code.id,
              imageFile: img,
            );
        await AvatarStore.clearLocal('member:${code.id}');
        avatarVersion.value++;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (pick == 'preset') {
      var selected = 1;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Аватар участника'),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: AvatarStore.totalAvatars,
                    itemBuilder: (_, i) {
                      final idx = i + 1;
                      final sel = idx == selected;
                      return GestureDetector(
                        onTap: () => setSt(() => selected = idx),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? kChildBrandBlue : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              AvatarStore.assetForIndex(idx),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: kFigmaLandingCtaHeight,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            kFigmaLandingCtaHeight / 2,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Сохранить'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FigmaDialogCancelButton(
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _busy = true);
      try {
        final data = await rootBundle.load(AvatarStore.assetForIndex(selected));
        final bytes = data.buffer.asUint8List();
        await ref
            .read(parentAccessRepositoryProvider)
            .uploadMemberCodeAvatarFromAsset(
              familyId: familyId,
              memberCodeId: code.id,
              pngBytes: bytes,
            );
        await AvatarStore.clearLocal('member:${code.id}');
        avatarVersion.value++;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _revokeChild(String childId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(parentAccessRepositoryProvider)
          .revokeChildDevices(childId);
      if (mounted) {
        context.showKlanySnackBar(
          const SnackBar(content: Text('Устройства ребёнка отключены')),
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
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
        context.showKlanySnackBar(
          const SnackBar(content: Text('Ребёнок деактивирован')),
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ребёнок будет удалён из семьи. Продолжить?'),
            const SizedBox(height: 16),
            FigmaDialogActionStack(
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
              confirmLabel: 'Удалить',
              confirmGradient:
                  FigmaDialogActionStack.destructiveGradientVertical,
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentAccessRepositoryProvider).deleteChild(childId);
      if (mounted) {
        context.showKlanySnackBar(
          const SnackBar(content: Text('Ребёнок удалён')),
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
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
    context.showKlanySnackBar(
      const SnackBar(content: Text('Обучение показано повторно')),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);

    return familyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
        List<FamilyMemberCodeItem>,
      )
    >(
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const FigmaAuthScreenBackground(),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final pageWidth = _settingsPageWidth(maxW);
                    final sidePadding = maxW < 430 ? 19.0 : 24.0;
                    return Center(
                      child: SizedBox(
                        width: pageWidth,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            filledButtonTheme: FilledButtonThemeData(
                              style: _figmaSettingsButtonStyle(
                                backgroundColor: _figmaSettingsMint,
                              ),
                            ),
                          ),
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              sidePadding,
                              31,
                              sidePadding,
                              40,
                            ),
                            children: [
                              Padding(
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  height: 48,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 48,
                                                  height: 48,
                                                ),
                                            icon: const Icon(
                                              Icons.arrow_back,
                                              color: Colors.black,
                                              size: 24,
                                            ),
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).maybePop(),
                                          ),
                                        ),
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Настройки',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 48,
                                                  height: 48,
                                                ),
                                            icon: const Icon(
                                              Icons.logout_outlined,
                                              color: Colors.black,
                                              size: 24,
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => ref
                                                      .read(authActionsProvider)
                                                      .signOut(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── Clan card (3 rows in one card) ───────────────────────────
                              _SCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    _ClanRow(
                                      avatarText:
                                          (family.clanName?.trim().isNotEmpty ==
                                                      true
                                                  ? family.clanName!
                                                  : 'К')
                                              .characters
                                              .first
                                              .toUpperCase(),
                                      title:
                                          family.clanName?.trim().isNotEmpty ==
                                              true
                                          ? family.clanName!
                                          : 'Клан',
                                      subtitle:
                                          'Family ID: ${family.familyCode}',
                                      subtitleColor: kChildBrandBlue,
                                      userKey: 'parent:${family.familyId}',
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: kChildOutline,
                                      ),
                                    ),
                                    _IconRow(
                                      icon: Icons.badge_outlined,
                                      title: 'Текущая учётная запись',
                                      subtitle: 'Без имени\nГлава семьи',
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: kChildOutline,
                                      ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _SectionTitle('Общая цель семьи'),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
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
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: kChildInk,
                                      ),
                                      decoration: _settingsField(
                                        'Купить велосипед',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
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
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: kChildInk,
                                      ),
                                      decoration: _settingsField(
                                        family.goalAmount > 0
                                            ? '${family.goalAmount}'
                                            : 'Купить велосипед',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      onPressed: _busy ? null : _saveGoal,
                                      style: _figmaSettingsButtonStyle(
                                        backgroundColor: _figmaSettingsMint,
                                      ),
                                      child: const Text('Сохранить цель'),
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
                                  final subs =
                                      subSnap.data ??
                                      const <FamilySubscriptionItem>[];
                                  final current = subs.isNotEmpty
                                      ? subs.first
                                      : null;
                                  final isPremium =
                                      current?.planCode.toLowerCase().contains(
                                        'premium',
                                      ) ==
                                      true;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (isPremium) ...[
                                        Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: _figmaSettingsLavender,
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                onPressed: _busy
                                                    ? null
                                                    : _buyPremium,
                                                style:
                                                    _figmaSettingsButtonStyle(
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                                child: const Text(
                                                  'Управлять подпиской',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        FilledButton(
                                          onPressed: _busy ? null : _buyPremium,
                                          style: _figmaSettingsButtonStyle(
                                            backgroundColor:
                                                _figmaSettingsSkyButton,
                                          ),
                                          child: const Text(
                                            'УПРАВЛЯТЬ ПОДПИСКОЙ',
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],

                                      // ── Economics ────────────────────────────────────────
                                      _SCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              onChanged: (v) =>
                                                  setState(() => _taxRate = v),
                                            ),
                                            const SizedBox(height: 16),
                                            const Divider(
                                              height: 1,
                                              color: kChildOutline,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Expanded(
                                                  child: Text(
                                                    'PIN-код для Экономики',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: kChildInk,
                                                    ),
                                                  ),
                                                ),
                                                Switch(
                                                  value: _pinEnabled,
                                                  activeTrackColor:
                                                      _figmaSettingsMint,
                                                  activeThumbColor:
                                                      Colors.white,
                                                  inactiveTrackColor:
                                                      kChildOutline,
                                                  inactiveThumbColor:
                                                      Colors.white,
                                                  onChanged: (v) => setState(
                                                    () => _pinEnabled = v,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(
                                              height: 1,
                                              color: kChildOutline,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Expanded(
                                                  child: Text(
                                                    'Родительский контроль обратных задач',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: kChildInk,
                                                    ),
                                                  ),
                                                ),
                                                Switch(
                                                  value: _parentalControl,
                                                  activeTrackColor:
                                                      _figmaSettingsMint,
                                                  activeThumbColor:
                                                      Colors.white,
                                                  inactiveTrackColor:
                                                      kChildOutline,
                                                  inactiveThumbColor:
                                                      Colors.white,
                                                  onChanged: (v) => setState(
                                                    () => _parentalControl = v,
                                                  ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _SectionTitle(
                                              'Подписка: ${current?.planCode ?? 'basic'}',
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 6,
                                                bottom: 6,
                                              ),
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
                                                fontFamily: 'Nunito',
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                                color: kChildInk,
                                              ),
                                              decoration: _settingsField(
                                                'промокод',
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            FilledButton(
                                              onPressed: _busy
                                                  ? null
                                                  : _activatePromo,
                                              style: _figmaSettingsButtonStyle(
                                                backgroundColor:
                                                    _figmaSettingsMint,
                                              ),
                                              child: const Text(
                                                'Активировать промокод',
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            FilledButton(
                                              onPressed: _busy
                                                  ? null
                                                  : _buyPremium,
                                              style: _figmaSettingsButtonStyle(
                                                backgroundColor:
                                                    _figmaSettingsSkyButton,
                                              ),
                                              child: const Text(
                                                'Оплатить премиум',
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                            final initial =
                                                c.displayName.isNotEmpty
                                                ? c.displayName[0].toUpperCase()
                                                : '?';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 10,
                                              ),
                                              child: _MemberTile(
                                                userKey: 'member:${c.id}',
                                                avatarFallback: initial,
                                                label: c.displayName,
                                                remoteImageUrl:
                                                    c.avatarImageUrl,
                                                onAvatarTap: _busy
                                                    ? null
                                                    : () => unawaited(
                                                        _editMemberAvatar(
                                                          family.familyId,
                                                          c,
                                                        ),
                                                      ),
                                              ),
                                            );
                                          }),
                                          // Add button as square tile
                                          Container(
                                            width: 76,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
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
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
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
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: kChildInk,
                                      ),
                                      decoration: _settingsField('Никита'),
                                    ),
                                    const SizedBox(height: 14),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
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
                                          fontFamily: 'Nunito',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
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
                                                  setState(
                                                    () => _memberRole = v,
                                                  );
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : _createMemberCode,
                                      style: _figmaSettingsButtonStyle(
                                        backgroundColor: _figmaSettingsMint,
                                      ),
                                      child: const Text('Добавить участника'),
                                    ),
                                    if (codes.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ...codes
                                          .take(12)
                                          .map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Color(
                                                            0xFFE3ECF8,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    alignment: Alignment.center,
                                                    child: UserAvatar(
                                                      userKey:
                                                          'member:${item.id}',
                                                      size: 40,
                                                      fallbackText:
                                                          item
                                                              .displayName
                                                              .isNotEmpty
                                                          ? item.displayName[0]
                                                                .toUpperCase()
                                                          : '?',
                                                      remoteImageUrl:
                                                          item.avatarImageUrl,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '${item.displayName} — ${item.code}',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    kChildInk,
                                                              ),
                                                        ),
                                                        Text(
                                                          familyMemberTypeLabel(
                                                            item.role,
                                                          ),
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                kChildInkMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 36,
                                                          minHeight: 36,
                                                        ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: const Icon(
                                                      Icons.share_outlined,
                                                      color: kChildBrandBlue,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => SharePlus
                                                        .instance
                                                        .share(
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _SectionTitle('Второй родитель'),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
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
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: kChildInk,
                                      ),
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
                                      onPressed: _busy
                                          ? null
                                          : () => _inviteByEmail(family),
                                      style: _figmaSettingsButtonStyle(
                                        backgroundColor: _figmaSettingsMint,
                                      ),
                                      child: const Text('Пригласить'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Support ──────────────────────────────────────────────────
                              _SCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _SectionTitle('Поддержка клана'),
                                    _SkyButton(
                                      label: 'Уведомления и лента семьи',
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const NotificationsPage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _SkyButton(
                                      label: 'Написать в поддержку',
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const TechSupportPage(),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _SectionTitle(
                                      'Юр. информация и Согласия',
                                    ),
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
                                          activeTrackColor: _figmaSettingsMint,
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
                                          activeTrackColor: _figmaSettingsMint,
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
                              const _ParentPremiumAnalyticsSection(),

                              // ── Parents ──────────────────────────────────────────────────
                              if (parents.isNotEmpty) ...[
                                _SCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Родители'),
                                      ...parents.map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p.displayName
                                                              .trim()
                                                              .isEmpty
                                                          ? 'Без имени'
                                                          : p.displayName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
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
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // ── Children ─────────────────────────────────────────────────
                              if (children.isNotEmpty) ...[
                                _SCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Дети'),
                                      ...children.map(
                                        (c) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      c.displayName
                                                              .trim()
                                                              .isEmpty
                                                          ? 'Без имени'
                                                          : c.displayName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: kChildInk,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Text(
                                                      c.isActive
                                                          ? 'Активен'
                                                          : 'Неактивен',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: c.isActive
                                                            ? const Color(
                                                                0xFF18B26B,
                                                              )
                                                            : kChildInkMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_horiz,
                                                  color: kChildInkMuted,
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'revoke') {
                                                    _revokeChild(c.childId);
                                                  } else if (value ==
                                                      'deactivate') {
                                                    _deactivateChild(c.childId);
                                                  } else if (value ==
                                                      'delete') {
                                                    _deleteChild(c.childId);
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    const [
                                                      PopupMenuItem(
                                                        value: 'revoke',
                                                        child: Text(
                                                          'Сбросить устройства',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'deactivate',
                                                        child: Text(
                                                          'Деактивировать',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Удалить'),
                                                      ),
                                                    ],
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                  size: 60,
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: widget.subtitleColor,
                    fontWeight: FontWeight.w400,
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
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3ECF8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: kChildInk, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
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
            final ratio = (d.localPosition.dx / constraints.maxWidth).clamp(
              0.0,
              1.0,
            );
            onChanged((ratio * 0.5).clamp(0.0, 0.5));
          },
          onHorizontalDragUpdate: (d) {
            final ratio = (d.localPosition.dx / constraints.maxWidth).clamp(
              0.0,
              1.0,
            );
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
                          left: i == 0
                              ? const Radius.circular(11)
                              : Radius.zero,
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
    required this.userKey,
    required this.avatarFallback,
    required this.label,
    this.remoteImageUrl,
    this.onAvatarTap,
  });
  final String userKey;
  final String avatarFallback;
  final String label;
  final String? remoteImageUrl;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
            child: UserAvatar(
              userKey: userKey,
              size: 56,
              fallbackText: avatarFallback,
              remoteImageUrl: remoteImageUrl,
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
    if (onAvatarTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAvatarTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }
    return card;
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
          backgroundColor: _figmaSettingsSkyButton,
          foregroundColor: kChildInk,
          elevation: 4,
          minimumSize: const Size.fromHeight(kFigmaLandingCtaHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFigmaLandingCtaHeight / 2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
