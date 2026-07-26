import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../auth/parent_access_repository.dart';
import '../../shop/pages/parent_shop_page.dart';
import '../../wallet/wallet_repository.dart';
import '../../wallet/family_economy.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/value_bump.dart';
import '../../home/parent_screen_header.dart';
import 'economy_figma_layout.dart';

const Color _kEconomyTitleBlue = EconomyFigmaLayout.titleBlue;

class ParentQuestsPage extends ConsumerStatefulWidget {
  const ParentQuestsPage({
    super.key,
    this.onBack,
    this.showShopShortcut = true,
    this.extraBottomPadding = 0,
  });

  final VoidCallback? onBack;
  final bool showShopShortcut;
  final double extraBottomPadding;

  @override
  ConsumerState<ParentQuestsPage> createState() => _ParentQuestsPageState();
}

class _ParentQuestsPageState extends ConsumerState<ParentQuestsPage> {
  int _selectedWallet = -1;
  List<ParentChildWalletItem> _wallets = const [];

  bool _walletsListenerSet = false;
  Timer? _economyPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
    _economyPoll = Timer.periodic(kParentLivePollInterval, (_) {
      _loadWallets();
      ref.invalidate(parentFamilyContextProvider);
    });
  }

  @override
  void dispose() {
    _economyPoll?.cancel();
    super.dispose();
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
    final currentRate = ref.read(familyCoinRateProvider);
    final ctrl = TextEditingController(text: currentRate.toString());
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
    if (rate != null && rate > 0) {
      try {
        await ref.read(familyCoinRateProvider.notifier).setRate(rate);
      } catch (e) {
        if (!mounted) return;
        context.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
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
    final rublesPer10Coins = ref.watch(familyCoinRateProvider);
    final sel = _selectedWallet >= 0 && _selectedWallet < _wallets.length
        ? _wallets[_selectedWallet]
        : null;

    final totalCoins =
        sel?.balance ?? _wallets.fold<int>(0, (a, w) => a + w.balance);
    final rubles = coinsToRubles(totalCoins, rublesPer10Coins);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ParentScreenHeader(
                      title: 'Экономика',
                      onBack: widget.onBack,
                      trailing: widget.showShopShortcut
                          ? DecoratedBox(
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
                                  child: SizedBox(
                                    width: EconomyFigmaLayout.shopBtnSize,
                                    height: EconomyFigmaLayout.shopBtnSize,
                                    child: Center(
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
                            )
                          : null,
                    ),

                    SizedBox(
                      height: EconomyFigmaLayout.walletRowHeight,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: EconomyFigmaLayout.hMargin,
                        ),
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

                    const SizedBox(height: 4),

                    _EconomyDivider(),

                    Padding(
                      padding: EconomyFigmaLayout.balancePad,
                      child: ValueBumpWrap(
                        changeKey:
                            '${totalCoins}_${rublesPer10Coins}_${sel?.childId ?? -1}',
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/figma/coin_stack.png',
                                  width: EconomyFigmaLayout.coinIconW,
                                  height: EconomyFigmaLayout.coinIconH,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatBalance(totalCoins),
                                  style: EconomyFigmaLayout.balanceStyle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: EconomyFigmaLayout.rublesFontSize,
                                  fontWeight: FontWeight.w400,
                                  color:
                                      Colors.black.withValues(alpha: 0.3),
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${_formatBalance(rubles)} ',
                                  ),
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
                    ),

                    _EconomyDivider(),

                    Padding(
                      padding: EconomyFigmaLayout.coinCardOuterPad,
                      child: Container(
                        padding: EconomyFigmaLayout.coinCardInnerPad,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            EconomyFigmaLayout.coinCardRadius,
                          ),
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
                                    style: EconomyFigmaLayout.sectionTitleStyle,
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
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Container(
                                height: 1,
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            InkWell(
                              onTap: _editCoinRate,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Курс',
                                          style:
                                              EconomyFigmaLayout.sectionTitleStyle,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '10 монет = $rublesPer10Coins ₽',
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
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 88 + widget.extraBottomPadding),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _EconomyDivider extends StatelessWidget {
  const _EconomyDivider({this.margin = EdgeInsets.zero});

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin.add(
        const EdgeInsets.symmetric(
          vertical: EconomyFigmaLayout.dividerVerticalPad,
        ),
      ),
      child: Container(
        height: EconomyFigmaLayout.dividerHeight,
        margin: const EdgeInsets.symmetric(
          horizontal: EconomyFigmaLayout.hMargin,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(
            EconomyFigmaLayout.dividerHeight,
          ),
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(EconomyFigmaLayout.walletChipPad),
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
              width: EconomyFigmaLayout.walletAvatar,
              height: EconomyFigmaLayout.walletAvatar,
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
                  ? Icon(icon, color: kChildInk, size: 30)
                  : (userKey != null
                      ? UserAvatar(
                          userKey: userKey!,
                          size: EconomyFigmaLayout.walletAvatar,
                          fallbackText: label.characters.first.toUpperCase(),
                        )
                      : Image.asset(
                          _avatarAssetForName(label),
                          width: EconomyFigmaLayout.walletAvatar,
                          height: EconomyFigmaLayout.walletAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Text(
                            label.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        )),
            ),
            const SizedBox(height: EconomyFigmaLayout.walletAvatarGap),
            SizedBox(
              width: EconomyFigmaLayout.walletLabelWidth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: EconomyFigmaLayout.walletLabelStyle,
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
          width: EconomyFigmaLayout.circleBtnSize,
          height: EconomyFigmaLayout.circleBtnSize,
          child: Icon(icon, color: kChildInk, size: 22),
        ),
      ),
    );
  }
}
