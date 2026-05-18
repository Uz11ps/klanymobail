import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../auth/parent_access_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/wallet_repository.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../quests_repository.dart';
import '../../../core/app_snackbar.dart';

const Color _kEconomyTitleBlue = Color(0xFF4563B1);
const Color _kFigmaReviewMint = Color(0xFFD9F6C2);
const Color _kFigmaReviewSky = Color(0xFFBFD3FF);
const Color _kFigmaReviewLavender = Color(0xFFD8CBF7);

InputDecoration _questCreateDropdownDecoration({Widget? prefix}) {
  return InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    prefixIcon: prefix,
  );
}

class ParentQuestsPage extends ConsumerStatefulWidget {
  const ParentQuestsPage({super.key});

  @override
  ConsumerState<ParentQuestsPage> createState() => _ParentQuestsPageState();
}

class _ParentQuestsPageState extends ConsumerState<ParentQuestsPage> {
  int _tab = 0;
  int _selectedWallet = -1;
  int _rublesPer10Coins = 100;
  List<ParentChildWalletItem> _wallets = const [];

  bool _walletsListenerSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_walletsListenerSet) {
      _walletsListenerSet = true;
      ref.listenManual<AsyncValue<ParentFamilyContext?>>(
        parentFamilyContextProvider,
        (prev, next) {
          if (next.asData?.value != null) {
            _loadWallets();
          }
        },
        fireImmediately: true,
      );
    }
  }

  Future<void> _loadWallets() async {
    final family = ref.read(parentFamilyContextProvider).asData?.value;
    if (family == null) return;
    try {
      final wallets = await ref
          .read(walletRepositoryProvider)
          .getFamilyWallets(family.familyId);
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
      });
    } catch (_) {}
  }

  Future<void> _showAdjustDialog(ParentChildWalletItem wallet) async {
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final modalW = figmaWideModalWidth(ctx);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: figmaWideModalInsets(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: modalW,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Корректировка: ${wallet.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kEconomyTitleBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Сумма (+/-)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Комментарий',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FigmaDialogActionStack(
                    onCancel: () => Navigator.pop(ctx, false),
                    onConfirm: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim());
    if (amount == null || amount == 0) return;
    try {
      await ref.read(walletRepositoryProvider).adjustWallet(
            childId: wallet.childId,
            amount: amount,
            note: commentCtrl.text.trim(),
          );
      await _loadWallets();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _editCoinRate() async {
    final ctrl = TextEditingController(text: _rublesPer10Coins.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final modalW = figmaWideModalWidth(ctx);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: figmaWideModalInsets(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: modalW,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Курс монет',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kEconomyTitleBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '10 монет = ? рублей',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FigmaDialogActionStack(
                    onCancel: () => Navigator.pop(ctx, false),
                    onConfirm: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    final rate = int.tryParse(ctrl.text.trim());
    if (rate != null && rate > 0) setState(() => _rublesPer10Coins = rate);
  }

  String _formatBalance(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(parentFamilyContextProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (family) {
            if (family == null) {
              return const Center(child: Text('Семья не найдена'));
            }
            return _buildPage(family);
          },
        );
  }

  Widget _buildPage(ParentFamilyContext family) {
    final sel = _selectedWallet >= 0 && _selectedWallet < _wallets.length
        ? _wallets[_selectedWallet]
        : null;

    final totalCoins =
        sel?.balance ?? _wallets.fold<int>(0, (a, w) => a + w.balance);
    final rubles = totalCoins * _rublesPer10Coins ~/ 10;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CloudBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 8, 19, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              'Экономика',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(41),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(41),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(41),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ParentShopPage(),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: SvgPicture.asset(
                                    'assets/figma/nav_shop.svg',
                                    width: 24,
                                    height: 24,
                                    colorFilter: const ColorFilter.mode(
                                      kChildInk,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      // 73 + отступы + подпись Nunito 16 — 124 было впритык и давало overflow 1–3 px.
                      height: 142,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(19, 0, 19, 0),
                        children: [
                          _WalletChip(
                            label: 'Все',
                            icon: Icons.person_outline,
                            selected: _selectedWallet == -1,
                            onTap: () => setState(() => _selectedWallet = -1),
                          ),
                          ..._wallets.asMap().entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: _WalletChip(
                                    label: e.value.displayName.trim().isEmpty
                                        ? '—'
                                        : e.value.displayName.trim(),
                                    userKey: 'child:${e.value.childId}',
                                    selected: _selectedWallet == e.key,
                                    onTap: () => setState(
                                      () => _selectedWallet = e.key,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),

                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 311,
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 20, 19, 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/figma/coin_stack.png',
                                width: 32,
                                height: 29,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatBalance(totalCoins),
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: _kEconomyTitleBlue,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                              children: [
                                TextSpan(text: '${_formatBalance(rubles)} '),
                                const TextSpan(
                                  text: '₽',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Center(
                      child: Container(
                        width: 311,
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 20, 19, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.13),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Управление монетами',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                _CircleIconBtn(
                                  icon: Icons.add,
                                  onTap: () => sel != null
                                      ? _showAdjustDialog(sel)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                _CircleIconBtn(
                                  icon: Icons.remove,
                                  onTap: () => sel != null
                                      ? _showAdjustDialog(sel)
                                      : null,
                                ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                              child: Container(
                                height: 1,
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            InkWell(
                              onTap: _editCoinRate,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Курс',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '10 монет = $_rublesPer10Coins ₽',
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: kChildInkMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Container(
                        width: 311,
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 20, 19, 15),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Биржа задач',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (routeCtx) => Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: CloudBackground(
                                    child: SafeArea(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              4,
                                              4,
                                              4,
                                              0,
                                            ),
                                            child: SizedBox(
                                              height: 48,
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 48,
                                                    child: IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints
                                                              .tightFor(
                                                        width: 48,
                                                        height: 48,
                                                      ),
                                                      icon: const Icon(
                                                        Icons
                                                            .arrow_back_rounded,
                                                        color: kChildInk,
                                                        size: 28,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.of(routeCtx)
                                                              .maybePop(),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      'Создать задачу',
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontFamily: 'Nunito',
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: kChildInk,
                                                        height: 1.15,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 48),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: _QuestCreateForm(
                                              familyId: family.familyId,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Добавить',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kEconomyTitleBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 19),
                      child: Row(
                        children: [
                          Expanded(
                            child: _EconomySegmentTab(
                              label: 'Активные',
                              selected: _tab == 0,
                              filled: false,
                              onTap: () => setState(() => _tab = 0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EconomySegmentTab(
                              label: 'Проверка',
                              selected: _tab == 2,
                              filled: true,
                              onTap: () => setState(() => _tab = 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_tab == 0)
                      _QuestsList(familyId: family.familyId)
                    else
                      _QuestReviewList(familyId: family.familyId),
                    const SizedBox(height: 120),
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

class _EconomySegmentTab extends StatelessWidget {
  const _EconomySegmentTab({
    required this.label,
    required this.selected,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration deco;
    if (filled) {
      if (selected) {
        deco = BoxDecoration(
          color: const Color(0xFFD9F6C2),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDEF7CB).withValues(alpha: 0.35),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: const Color(0xFFADD3A5).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 13),
            ),
          ],
        );
      } else {
        deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        );
      }
    } else if (selected) {
      deco = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.black.withValues(alpha: 0.34)),
      );
    } else {
      deco = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      );
    }

    Widget child = Container(
      height: 54,
      alignment: Alignment.center,
      decoration: deco,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );

    if (!filled && selected) {
      child = Opacity(opacity: 0.58, child: child);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _WalletChip extends StatelessWidget {
  const _WalletChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.userKey,
  });
  final String label;
  final String? userKey;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  static String _avatarAssetForName(String name) {
    final idx = (name.hashCode.abs() % 9) + 1;
    return 'assets/figma/avatar_$idx.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(
                  color: Colors.black.withValues(alpha: 0.29),
                  width: 0.4,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: selected ? 0.1 : 0.08,
              ),
              blurRadius: selected ? 20 : 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 73,
              height: 73,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.21),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, color: kChildInk, size: 33)
                  : (userKey != null
                      ? UserAvatar(
                          userKey: userKey!,
                          size: 73,
                          fallbackText: label.characters.first.toUpperCase(),
                        )
                      : Image.asset(
                          _avatarAssetForName(label),
                          width: 73,
                          height: 73,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Text(
                            label.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 22),
                          ),
                        )),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 80,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.0,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quests list ──────────────────────────────────────────────────────────────

class _QuestsList extends ConsumerStatefulWidget {
  const _QuestsList({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_QuestsList> createState() => _QuestsListState();
}

class _QuestsListState extends ConsumerState<_QuestsList> {
  Future<List<ParentQuestItem>>? _future;

  void _reload() {
    setState(() {
      _future =
          ref.read(questsRepositoryProvider).getParentQuests(widget.familyId);
    });
  }

  Future<void> _editQuest(ParentQuestItem q) async {
    final repo = ref.read(questsRepositoryProvider);
    final children = await repo.getFamilyChildren(widget.familyId);
    if (!mounted) return;

    final titleCtl = TextEditingController(text: q.title);
    final descriptionCtl = TextEditingController(text: q.description);
    final rewardCtl =
        TextEditingController(text: q.rewardAmount.toString());
    final hoursCtl = TextEditingController(
      text: ((q.timeLimitMinutes ?? 0) ~/ 60).toString(),
    );
    final minutesCtl = TextEditingController(
      text: ((q.timeLimitMinutes ?? 0) % 60).toString(),
    );
    final statuses = <String>['active', 'closed', 'archived'];
    var status = q.status.isEmpty ? 'active' : q.status;
    if (!statuses.contains(status)) statuses.add(status);
    var type = q.questType.isEmpty ? 'one_time' : q.questType;
    var distributionType = q.distributionType == 'exchange'
        ? 'exchange'
        : q.distributionType == 'reverse'
            ? 'reverse'
            : 'assigned';
    var autoApprove = q.autoApprove;
    var hasTimeLimit = q.timeLimitMinutes != null;
    var scheduleType = q.scheduleType == 'daily' ||
            q.scheduleType == 'weekly' ||
            q.scheduleType == 'custom_days'
        ? q.scheduleType
        : (type == 'recurring' ? 'daily' : 'none');
    final scheduleDays = <String>{...q.scheduleDays};
    final selectedChildren = <String>{...q.childIds};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Редактировать квест'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'recurring',
                        child: Text('Повторяющаяся'),
                      ),
                      DropdownMenuItem(
                        value: 'one_time',
                        child: Text('Разовая'),
                      ),
                      DropdownMenuItem(
                        value: 'unique',
                        child: Text('Уникальная'),
                      ),
                    ],
                    onChanged: (v) {
                      setLocalState(() {
                        type = v ?? 'one_time';
                        if (type != 'recurring') {
                          scheduleType = 'none';
                          scheduleDays.clear();
                        } else if (scheduleType == 'none') {
                          scheduleType = 'daily';
                        }
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Тип'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rewardCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Награда'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Статус'),
                    items: statuses
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: distributionType,
                    items: distributionType == 'reverse'
                        ? const [
                            DropdownMenuItem(
                              value: 'reverse',
                              child: Text('От ребёнка (обратная)'),
                            ),
                          ]
                        : const [
                            DropdownMenuItem(
                              value: 'assigned',
                              child: Text('Адресное назначение'),
                            ),
                            DropdownMenuItem(
                              value: 'exchange',
                              child: Text('Биржа задач'),
                            ),
                          ],
                    onChanged: distributionType == 'reverse'
                        ? null
                        : (v) => setLocalState(
                            () => distributionType = v ?? 'assigned',
                          ),
                    decoration: const InputDecoration(
                      labelText: 'Распределение',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: autoApprove,
                    onChanged: (v) => setLocalState(() => autoApprove = v),
                    title: const Text('Автоподтверждение'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: hasTimeLimit,
                    onChanged: (v) =>
                        setLocalState(() => hasTimeLimit = v == true),
                    title: const Text('Лимит времени'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasTimeLimit)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursCtl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Часы'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: minutesCtl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Минуты'),
                          ),
                        ),
                      ],
                    ),
                  if (type == 'recurring') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          scheduleType == 'none' ? 'daily' : scheduleType,
                      items: const [
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Ежедневно'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Еженедельно'),
                        ),
                        DropdownMenuItem(
                          value: 'custom_days',
                          child: Text('По выбранным дням'),
                        ),
                      ],
                      onChanged: (v) =>
                          setLocalState(() => scheduleType = v ?? 'daily'),
                      decoration: const InputDecoration(
                        labelText: 'График повторения',
                      ),
                    ),
                    if (scheduleType == 'custom_days') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          ('mon', 'Пн'),
                          ('tue', 'Вт'),
                          ('wed', 'Ср'),
                          ('thu', 'Чт'),
                          ('fri', 'Пт'),
                          ('sat', 'Сб'),
                          ('sun', 'Вс'),
                        ]
                            .map(
                              (d) => FilterChip(
                                label: Text(d.$2),
                                selected: scheduleDays.contains(d.$1),
                                onSelected: (selected) {
                                  setLocalState(() {
                                    if (selected) {
                                      scheduleDays.add(d.$1);
                                    } else {
                                      scheduleDays.remove(d.$1);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  if (distributionType == 'exchange')
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront),
                      title: Text('Задача будет опубликована на Бирже'),
                    ),
                  if (distributionType == 'assigned')
                    ...children.map(
                      (child) => CheckboxListTile(
                        value: selectedChildren.contains(child.id),
                        title: Text(child.displayName),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setLocalState(() {
                            if (v == true) {
                              selectedChildren.add(child.id);
                            } else {
                              selectedChildren.remove(child.id);
                            }
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  FigmaDialogActionStack(
                    onCancel: () => Navigator.pop(ctx, false),
                    onConfirm: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final reward = int.tryParse(rewardCtl.text.trim());
    if (reward == null || reward < 0) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Награда должна быть >= 0')),
      );
      return;
    }
    final totalMinutes =
        (int.tryParse(hoursCtl.text.trim()) ?? 0) * 60 +
        (int.tryParse(minutesCtl.text.trim()) ?? 0);
    if (hasTimeLimit && totalMinutes <= 0) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Укажите лимит времени больше 0')),
      );
      return;
    }
    if (distributionType == 'assigned' && selectedChildren.isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного ребёнка')),
      );
      return;
    }
    if (type == 'recurring' &&
        scheduleType == 'custom_days' &&
        scheduleDays.isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день повторения')),
      );
      return;
    }
    await repo.updateQuest(
      questId: q.id,
      title: titleCtl.text.trim(),
      description: descriptionCtl.text.trim(),
      rewardAmount: reward,
      questType: type,
      status: status,
      childIds: distributionType == 'assigned'
          ? selectedChildren.toList()
          : const <String>[],
      distributionType: distributionType,
      autoApprove: autoApprove,
      timeLimitMinutes: hasTimeLimit ? totalMinutes : null,
      scheduleType: type == 'recurring' ? scheduleType : 'none',
      scheduleDays: type == 'recurring'
          ? scheduleDays.toList()
          : const <String>[],
    );
    if (!mounted) return;
    _reload();
    context.showKlanySnackBar(const SnackBar(content: Text('Квест обновлён')));
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel(String v) => switch (v) {
          'recurring' => 'Повторяющаяся',
          'unique' => 'Уникальная',
          _ => 'Разовая',
        };

    String distributionSubtitle(ParentQuestItem q) => switch (
          q.distributionType) {
      'exchange' => 'Биржа',
      'reverse' =>
        'От ребёнка • монеты уже списаны с его счёта — закройте после выполнения',
      _ => 'Адресно',
    };

    return FutureBuilder<List<ParentQuestItem>>(
      future: _future ??
          ref.read(questsRepositoryProvider).getParentQuests(widget.familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentQuestItem>[];
        final shown = list
            .where((q) => q.distributionType != 'reverse')
            .toList();
        final onlyReverseQueued = shown.isEmpty &&
            list.any((q) => q.distributionType == 'reverse');
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 19),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (snapshot.hasError)
              Text('Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            if (shown.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    onlyReverseQueued
                        ? 'Задачи к вам от ребёнка — в колокольчике уведомлений «К вам от ребёнка»'
                        : 'Нет задач',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kChildInkMuted),
                  ),
                ),
              ),
            ...shown.asMap().entries.map(
              (e) {
                final q = e.value;
                final colors = _reviewCardColors;
                final cardColor = colors[e.key % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(15, 20, 12, 20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withValues(alpha: 0.35),
                            blurRadius: 50,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color: _figmaReviewCardShadow2(cardColor),
                            blurRadius: 20,
                            offset: const Offset(0, 13),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.title,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  '+${q.rewardAmount} монет',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${typeLabel(q.questType)} • ${distributionSubtitle(q)}',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black.withValues(alpha: 0.45),
                                  ),
                                ),
                                Text(
                                  '${q.status} • ${DateFormat('dd.MM HH:mm').format(q.createdAt.toLocal())}',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.38),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editQuest(q);
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить квест'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Удалить квест полностью?'),
                                const SizedBox(height: 16),
                                FigmaDialogActionStack(
                                  onCancel: () => Navigator.pop(ctx, false),
                                  onConfirm: () => Navigator.pop(ctx, true),
                                  confirmLabel: 'Удалить',
                                  confirmGradient:
                                      FigmaDialogActionStack
                                          .destructiveGradientVertical,
                                ),
                              ],
                            ),
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(questsRepositoryProvider)
                              .deleteQuest(q.id);
                          if (!context.mounted) return;
                          _reload();
                          context.showKlanySnackBar(
                            const SnackBar(content: Text('Квест удалён')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить'),
                      ),
                    ],
                  ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── Quest create form ────────────────────────────────────────────────────────

class _QuestCreateForm extends ConsumerStatefulWidget {
  const _QuestCreateForm({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_QuestCreateForm> createState() => _QuestCreateFormState();
}

class _QuestCreateFormState extends ConsumerState<_QuestCreateForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController(text: '10');
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();
  String _type = 'one_time';
  String _distributionType = 'assigned';
  bool _autoApprove = false;
  bool _hasTimeLimit = false;
  String _scheduleType = 'none';
  bool _usePreset = true;
  String _preset = 'custom';
  final Set<String> _scheduleDays = {};
  final Set<String> _selectedChildren = {};
  bool _busy = false;

  static const Map<String, List<String>> _presets = {
    'recurring': [
      'Встать с кровати',
      'Заправить кровать',
      'Почистить зубы',
      'Умыться',
      'Сделать зарядку',
      'Выпить стакан воды',
      'Выгулять собаку',
      'Насыпать корм питомцу',
      'Собрать рюкзак',
      'Сдать телефон родителям',
      'Вынести мусор',
      'Вымыть свою посуду',
      'Сделать уроки',
      'Занятие музыкой',
    ],
    'one_time': [
      'Сходить в магазин',
      'Помыть посуду',
      'Почистить обувь',
      'Провести влажную уборку',
      'Пропылесосить',
      'Приготовить еду',
    ],
    'unique': [
      'Прочитать 10 страниц',
      'Выучить 5 иностранных слов',
      'Исправить оценку',
      'Хорошо выступить на соревнованиях',
    ],
  };

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reward.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  List<String> get _presetItems => ['custom', ...(_presets[_type] ?? [])];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyChildLite>>(
      future: ref
          .read(questsRepositoryProvider)
          .getFamilyChildren(widget.familyId),
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <FamilyChildLite>[];
        return Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(19, 8, 19, 28),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: kChildBrandBlue,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Тип', style: kFigmaAuthFieldLabelStyle),
                ),
              ),
              FigmaAuthInputShell(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('qcreate_type_$_type'),
                  isExpanded: true,
                  initialValue: _type,
                  style: kFigmaAuthInputTextStyle,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kChildInkMuted,
                  ),
                  dropdownColor: Colors.white,
                  decoration: _questCreateDropdownDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'recurring',
                      child: Text('Повторяющаяся'),
                    ),
                    DropdownMenuItem(
                      value: 'one_time',
                      child: Text('Разовая'),
                    ),
                    DropdownMenuItem(
                      value: 'unique',
                      child: Text('Уникальная'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v ?? 'one_time';
                    _preset = 'custom';
                    _title.clear();
                    _scheduleType = _type == 'recurring' ? 'daily' : 'none';
                    _scheduleDays.clear();
                  }),
                ),
              ),
              SizedBox(height: kFigmaAuthFieldStackGap),
              ChildSoftCard(
                color: Colors.white,
                radius: 22,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: CheckboxListTile(
                  value: _usePreset,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  activeColor: kChildBrandBlue,
                  title: const Text(
                    'Выбрать из базового списка',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                  subtitle: const Text(
                    'Снимите, если нужна своя задача',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kChildInkMuted,
                      height: 1.35,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    _usePreset = v == true;
                    _preset = 'custom';
                    _title.clear();
                  }),
                ),
              ),
              if (_usePreset) ...[
                SizedBox(height: kFigmaAuthFieldStackGap),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Выбор задачи',
                      style: kFigmaAuthFieldLabelStyle,
                    ),
                  ),
                ),
                FigmaAuthInputShell(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('qcreate_preset_$_preset'),
                    isExpanded: true,
                    initialValue: _preset,
                    style: kFigmaAuthInputTextStyle,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kChildInkMuted,
                    ),
                    dropdownColor: Colors.white,
                    decoration: _questCreateDropdownDecoration(
                      prefix: Icon(
                        Icons.playlist_add_check_rounded,
                        color: kChildInkMuted,
                        size: 22,
                      ),
                    ),
                    items: _presetItems
                        .map(
                          (title) => DropdownMenuItem<String>(
                            value: title,
                            child: Text(
                              title == 'custom' ? 'Свободная задача' : title,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _preset = v ?? 'custom';
                      if (_preset != 'custom') _title.text = _preset;
                    }),
                  ),
                ),
              ],
              if (!_usePreset || _preset == 'custom') ...[
                SizedBox(height: kFigmaAuthFieldStackGap),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Название',
                      style: kFigmaAuthFieldLabelStyle,
                    ),
                  ),
                ),
                FigmaAuthInputShell(
                  child: TextFormField(
                    controller: _title,
                    style: kFigmaAuthInputTextStyle,
                    decoration: figmaAuthFieldDecoration('Кратко, о чём задача'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Введите название' : null,
                  ),
                ),
              ],
              SizedBox(height: kFigmaAuthFieldStackGap),
              Padding(
                padding: const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Описание', style: kFigmaAuthFieldLabelStyle),
                ),
              ),
              FigmaAuthInputShell(
                child: TextFormField(
                  controller: _description,
                  maxLines: 4,
                  style: kFigmaAuthInputTextStyle,
                  decoration: figmaAuthFieldDecoration(
                    'Детали и условия (по желанию)',
                  ),
                ),
              ),
              SizedBox(height: kFigmaAuthFieldStackGap),
              Padding(
                padding: const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Распределение', style: kFigmaAuthFieldLabelStyle),
                ),
              ),
              FigmaAuthInputShell(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('qcreate_dist_$_distributionType'),
                  isExpanded: true,
                  initialValue: _distributionType,
                  style: kFigmaAuthInputTextStyle,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kChildInkMuted,
                  ),
                  dropdownColor: Colors.white,
                  decoration: _questCreateDropdownDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'assigned',
                      child: Text('Адресное назначение'),
                    ),
                    DropdownMenuItem(
                      value: 'exchange',
                      child: Text('Биржа задач'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _distributionType = v ?? 'assigned'),
                ),
              ),
              SizedBox(height: kFigmaAuthFieldStackGap),
              ChildSoftCard(
                color: Colors.white,
                radius: 22,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SwitchListTile(
                  value: _autoApprove,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  activeTrackColor: kBrandMint,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: kChildOutline,
                  title: const Text(
                    'Автоподтверждение',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                  subtitle: const Text(
                    'Награда зачисляется сразу после выполнения',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kChildInkMuted,
                      height: 1.35,
                    ),
                  ),
                  onChanged: (v) => setState(() => _autoApprove = v),
                ),
              ),
              SizedBox(height: kFigmaAuthFieldStackGap),
              ChildSoftCard(
                color: Colors.white,
                radius: 22,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: CheckboxListTile(
                  value: _hasTimeLimit,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  activeColor: kChildBrandBlue,
                  title: const Text(
                    'Лимит времени',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) =>
                      setState(() => _hasTimeLimit = v == true),
                ),
              ),
              if (_hasTimeLimit) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: kFigmaAuthLabelToFieldGap,
                            ),
                            child: Text(
                              'Часы',
                              style: kFigmaAuthFieldLabelStyle,
                            ),
                          ),
                          FigmaAuthInputShell(
                            child: TextFormField(
                              controller: _hours,
                              keyboardType: TextInputType.number,
                              style: kFigmaAuthInputTextStyle,
                              decoration: figmaAuthFieldDecoration('0'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: kFigmaAuthLabelToFieldGap,
                            ),
                            child: Text(
                              'Минуты',
                              style: kFigmaAuthFieldLabelStyle,
                            ),
                          ),
                          FigmaAuthInputShell(
                            child: TextFormField(
                              controller: _minutes,
                              keyboardType: TextInputType.number,
                              style: kFigmaAuthInputTextStyle,
                              decoration: figmaAuthFieldDecoration('0'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (_type == 'recurring') ...[
                SizedBox(height: kFigmaAuthFieldStackGap),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'График повторения',
                      style: kFigmaAuthFieldLabelStyle,
                    ),
                  ),
                ),
                FigmaAuthInputShell(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('qcreate_sched_$_scheduleType'),
                    isExpanded: true,
                    initialValue: _scheduleType,
                    style: kFigmaAuthInputTextStyle,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kChildInkMuted,
                    ),
                    dropdownColor: Colors.white,
                    decoration: _questCreateDropdownDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('Ежедневно'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Еженедельно'),
                      ),
                      DropdownMenuItem(
                        value: 'custom_days',
                        child: Text('По выбранным дням'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _scheduleType = v ?? 'daily'),
                  ),
                ),
                if (_scheduleType == 'custom_days') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('mon', 'Пн'),
                      ('tue', 'Вт'),
                      ('wed', 'Ср'),
                      ('thu', 'Чт'),
                      ('fri', 'Пт'),
                      ('sat', 'Сб'),
                      ('sun', 'Вс'),
                    ]
                        .map(
                          (d) => FilterChip(
                            label: Text(
                              d.$2,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            selected: _scheduleDays.contains(d.$1),
                            selectedColor: kBrandMint,
                            checkmarkColor: kChildInk,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _scheduleDays.add(d.$1);
                                } else {
                                  _scheduleDays.remove(d.$1);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
              SizedBox(height: kFigmaAuthFieldStackGap),
              Padding(
                padding: const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Награда (монеты)',
                    style: kFigmaAuthFieldLabelStyle,
                  ),
                ),
              ),
              FigmaAuthInputShell(
                child: TextFormField(
                  controller: _reward,
                  keyboardType: TextInputType.number,
                  style: kFigmaAuthInputTextStyle,
                  decoration: figmaAuthFieldDecoration('10'),
                  validator: (v) {
                    final value = int.tryParse((v ?? '').trim());
                    if (value == null || value < 0) {
                      return 'Укажите число >= 0';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: kFigmaAuthFieldStackGap),
              Padding(
                padding: const EdgeInsets.only(bottom: kFigmaAuthLabelToFieldGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Исполнители',
                    style: kFigmaAuthFieldLabelStyle,
                  ),
                ),
              ),
              if (_distributionType == 'exchange')
                ChildSoftCard(
                  color: Colors.white,
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.storefront_rounded,
                      color: kChildBrandBlue,
                      size: 28,
                    ),
                    title: const Text(
                      'Задача будет опубликована на Бирже',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    subtitle: const Text(
                      'Любой ребёнок сможет взять её в работу',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kChildInkMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              if (_distributionType == 'assigned')
                ChildSoftCard(
                  color: Colors.white,
                  radius: 22,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: children.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Нет детей в семье',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: kChildInkMuted,
                                ),
                              ),
                            ),
                          ]
                        : children
                            .map(
                              (child) => CheckboxListTile(
                                value: _selectedChildren.contains(child.id),
                                activeColor: kChildBrandBlue,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                title: Text(
                                  child.displayName,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: kChildInk,
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedChildren.add(child.id);
                                    } else {
                                      _selectedChildren.remove(child.id);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                ),
              SizedBox(height: kFigmaAuthBeforePrimaryCtaGap),
              if (_busy)
                const SizedBox(
                  height: kFigmaAuthPrimaryCtaHeight,
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1F4F1B),
                      ),
                    ),
                  ),
                )
              else
                FigmaGradientButton(
                  label: 'Создать квест',
                  gradient: FigmaGradientButton.mintGradientVertical,
                  height: kFigmaAuthPrimaryCtaHeight,
                  labelStyle: kFigmaLandingCtaTextStyle,
                  boxShadow: kFigmaLandingCtaBoxShadows,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  onTap: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    if (_distributionType == 'assigned' &&
                        _selectedChildren.isEmpty) {
                      context.showKlanySnackBar(
                        const SnackBar(
                          content: Text('Выберите хотя бы одного ребёнка'),
                        ),
                      );
                      return;
                    }
                    final hours = int.tryParse(_hours.text.trim()) ?? 0;
                    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
                    final totalMinutes = hours * 60 + minutes;
                    if (_hasTimeLimit && totalMinutes <= 0) {
                      context.showKlanySnackBar(
                        const SnackBar(
                          content: Text('Укажите лимит времени больше 0'),
                        ),
                      );
                      return;
                    }
                    if (_type == 'recurring' &&
                        _scheduleType == 'custom_days' &&
                        _scheduleDays.isEmpty) {
                      context.showKlanySnackBar(
                        const SnackBar(
                          content: Text('Выберите хотя бы один день повторения'),
                        ),
                      );
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await ref.read(questsRepositoryProvider).createQuest(
                            title: _title.text,
                            description: _description.text,
                            rewardAmount: int.parse(_reward.text.trim()),
                            questType: _type,
                            dueAt: null,
                            childIds: _distributionType == 'assigned'
                                ? _selectedChildren.toList()
                                : const [],
                            distributionType: _distributionType,
                            autoApprove: _autoApprove,
                            timeLimitMinutes:
                                _hasTimeLimit ? totalMinutes : null,
                            scheduleType: _type == 'recurring'
                                ? _scheduleType
                                : 'none',
                            scheduleDays: _type == 'recurring'
                                ? _scheduleDays.toList()
                                : const [],
                          );
                      if (!context.mounted) return;
                      context.showKlanySnackBar(
                        const SnackBar(content: Text('Квест создан')),
                      );
                      _title.clear();
                      _description.clear();
                      _reward.text = '10';
                      _hours.text = '0';
                      _minutes.text = '0';
                      setState(() {
                        _selectedChildren.clear();
                        _scheduleDays.clear();
                        _preset = 'custom';
                        _usePreset = true;
                        _distributionType = 'assigned';
                        _autoApprove = false;
                        _hasTimeLimit = false;
                        _type = 'one_time';
                        _scheduleType = 'none';
                      });
                    } catch (e) {
                      if (!context.mounted) return;
                      context.showKlanySnackBar(
                        SnackBar(content: Text('Ошибка создания: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Quest review list ────────────────────────────────────────────────────────

const _reviewCardColors = <Color>[
  _kFigmaReviewMint,
  _kFigmaReviewSky,
  _kFigmaReviewLavender,
];

Color _figmaReviewCardShadow2(Color bg) {
  switch (bg.toARGB32()) {
    case 0xFFD9F6C2:
      return const Color(0xFFADD3A5).withValues(alpha: 0.35);
    case 0xFFBFD3FF:
      return const Color(0xFFBFD3FF).withValues(alpha: 0.35);
    default:
      return const Color(0xFFB3A5D3).withValues(alpha: 0.35);
  }
}

class _QuestReviewList extends ConsumerWidget {
  const _QuestReviewList({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ParentReviewItem>>(
      future:
          ref.read(questsRepositoryProvider).getSubmittedForReview(familyId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <ParentReviewItem>[];
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (snapshot.hasError)
              Text('Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            if (list.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Нет заявок на проверку',
                    style: TextStyle(color: kChildInkMuted),
                  ),
                ),
              ),
            ...list.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(
                      item: e.value,
                      bg: _reviewCardColors[e.key % _reviewCardColors.length],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.item, required this.bg});
  final ParentReviewItem item;
  final Color bg;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _busy = false;

  Future<void> _review(bool approve, {String comment = ''}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(questsRepositoryProvider).reviewSubmission(
            questId: widget.item.questId,
            childId: widget.item.childId,
            approve: approve,
            comment: comment,
          );
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(
          content:
              Text(approve ? 'Задание подтверждено' : 'Задание отклонено'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReviewSheet() async {
    final commentCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kChildInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Исполнитель: ${widget.item.childName}',
              style: const TextStyle(fontSize: 13, color: kChildInkMuted),
            ),
            if (widget.item.submittedAt != null)
              Text(
                'Отправлено: ${DateFormat('dd.MM HH:mm').format(widget.item.submittedAt!.toLocal())}',
                style: const TextStyle(fontSize: 13, color: kChildInkMuted),
              ),
            if ((widget.item.evidenceUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    widget.item.evidenceUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFEFF2F8),
                      alignment: Alignment.center,
                      child: const Text('Не удалось загрузить фото'),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(hintText: 'Комментарий'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Подтвердить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await _review(result, comment: commentCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.item.rewardAmount;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: _busy ? null : _openReviewSheet,
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: widget.bg.withValues(alpha: 0.35),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: _figmaReviewCardShadow2(widget.bg),
                blurRadius: 20,
                offset: const Offset(0, 13),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              if (reward != null)
                Text(
                  '$reward монет',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              const SizedBox(height: 15),
              Text(
                widget.item.childName,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.black.withValues(alpha: 0.21),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 57,
          height: 57,
          child: Icon(icon, color: kChildInk, size: 24),
        ),
      ),
    );
  }
}
