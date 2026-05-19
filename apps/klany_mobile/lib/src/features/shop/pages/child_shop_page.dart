import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/child_session.dart';
import '../../home/child_dashboard_profile_card.dart';
import '../../home/child_soft_ui.dart';
import '../../quests/quests_repository.dart';
import '../../wallet/wallet_repository.dart';
import '../../../core/api_client.dart';
import '../shop_product_cached_image.dart';
import '../shop_product_icon.dart';
import '../shop_repository.dart';
import '../../../core/app_snackbar.dart';

/// Те же заливки карточек, что у квестов/биржи ([Figma]).
const _kMintCard = Color(0xFFD9F6C2);
const _kLavenderCard = Color(0xFFD8CBF7);
const _kSkyCard = Color(0xFFC1DCF5);

const _shopCardColors = <Color>[_kMintCard, _kSkyCard, _kLavenderCard];

List<BoxShadow> _shopProductOuterShadows(Color bg) {
  if (bg == _kMintCard) {
    return [
      BoxShadow(
        color: const Color.fromRGBO(222, 247, 203, 0.35),
        blurRadius: 50,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: const Color.fromRGBO(173, 211, 165, 0.35),
        blurRadius: 20,
        offset: const Offset(0, 13),
      ),
    ];
  }
  if (bg == _kLavenderCard) {
    return [
      BoxShadow(
        color: const Color.fromRGBO(216, 203, 247, 0.35),
        blurRadius: 50,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: const Color.fromRGBO(179, 165, 211, 0.35),
        blurRadius: 20,
        offset: const Offset(0, 13),
      ),
    ];
  }
  return [
    BoxShadow(
      color: const Color.fromRGBO(193, 220, 255, 0.35),
      blurRadius: 50,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: const Color.fromRGBO(191, 219, 255, 0.35),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

Widget _shopDividerLine() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = math.min(
        constraints.maxWidth,
        constraints.maxWidth * (311 / 353),
      );
      return Center(
        child: SizedBox(
          width: w,
          height: 1,
          child: Image.asset(
            'assets/figma/child_dashboard_divider.png',
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ChildShopPage extends ConsumerStatefulWidget {
  const ChildShopPage({super.key});

  @override
  ConsumerState<ChildShopPage> createState() => _ChildShopPageState();
}

class _ChildShopPageState extends ConsumerState<ChildShopPage> {
  late Future<_ChildShopData> _future;
  String? _familyId;
  String? _childId;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  void _fetchAll() {
    final childSession = ref.read(childSessionProvider).asData?.value;
    _familyId = childSession?.familyId;
    _childId = childSession?.childId;
    _future = _load();
  }

  Future<_ChildShopData> _load() async {
    final products = await ref
        .read(shopRepositoryProvider)
        .getProducts(_familyId ?? '');
    var completed = 0;
    var balance = 0;
    if ((_childId ?? '').isNotEmpty) {
      try {
        final wallet = await ref
            .read(walletRepositoryProvider)
            .getChildWallet(_childId!);
        balance = wallet?.balance ?? 0;
      } catch (_) {}
      try {
        final assignments = await ref
            .read(questsRepositoryProvider)
            .getChildAssignments(_childId!);
        completed = assignments
            .where(
              (a) =>
                  a.status == 'completed' ||
                  a.status == 'done' ||
                  a.status == 'approved',
            )
            .length;
      } catch (_) {}
    }
    return _ChildShopData(
      products: products,
      completedCount: completed,
      balance: balance,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _buy(ShopProductItem p) async {
    try {
      await ref.read(shopRepositoryProvider).requestPurchase(p.id);
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Запрос отправлен, средства заморожены')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      context.showKlanySnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session?.familyId != _familyId || session?.childId != _childId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fetchAll());
      });
    }

    if (session == null) {
      return const Center(child: Text('Сессия ребёнка не найдена'));
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final cw = kFigmaChildDashboardContentWidth(screenW);
    final hPad = kFigmaChildDashboardHorizontalPadding(screenW, cw);
    final bottomPad = ChildBottomClanBar.scrollBottomClearance(context) + 28;

    return FutureBuilder<_ChildShopData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final products = data?.products ?? const <ShopProductItem>[];
        final completed = data?.completedCount ?? 0;
        final balance = data?.balance ?? 0;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/figma/child_dashboard_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: kBgCloud.withValues(alpha: 0.35)),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFF5F7FB).withValues(alpha: 0.66),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(hPad, 26, hPad, bottomPad),
                    children: [
                      SizedBox(
                        width: cw,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                              child: Text(
                                'Магазин наград',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _refresh,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: SvgPicture.asset(
                                        'assets/figma/nav_refresh.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.black,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ChildDashboardProfileCard(completedCount: completed),
                      const SizedBox(height: 20),
                      _shopDividerLine(),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (snapshot.hasError)
                        ChildSoftCard(child: Text('Ошибка: ${snapshot.error}')),
                      if (!snapshot.hasError &&
                          snapshot.connectionState != ConnectionState.waiting &&
                          products.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'Пока нет доступных товаров',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: kChildInkMuted.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ...products.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ChildShopProductCard(
                            product: e.value,
                            balance: balance,
                            bg: _shopCardColors[e.key % _shopCardColors.length],
                            onTap: e.value.isActive
                                ? () {
                                    if (balance < e.value.price) {
                                      if (!context.mounted) return;
                                      context.showKlanySnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Нужно ${e.value.price} монет, у вас $balance.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    _buy(e.value);
                                  }
                                : () {
                                    if (!context.mounted) return;
                                    context.showKlanySnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Этот товар сейчас недоступен',
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildShopData {
  _ChildShopData({
    required this.products,
    required this.completedCount,
    required this.balance,
  });

  final List<ShopProductItem> products;
  final int completedCount;
  final int balance;
}

class _ChildShopProductCard extends StatelessWidget {
  const _ChildShopProductCard({
    required this.product,
    required this.balance,
    required this.bg,
    required this.onTap,
  });

  final ShopProductItem product;
  final int balance;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = product.isActive;
    final canAfford = balance >= product.price;
    final insufficient = active && !canAfford;

    final titleStyle = GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: active ? kChildInk : kChildInk.withValues(alpha: 0.42),
      height: 1.15,
    );
    final priceStyle = GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: active ? kChildInk : kChildInk.withValues(alpha: 0.38),
    );
    final btnLabel = !active
        ? 'Недоступно'
        : insufficient
            ? 'Недостаточно монет'
            : 'Запросить награду';

    return Opacity(
      opacity: active ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: _shopProductOuterShadows(bg),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: (product.imageUrl ?? '').isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ShopProductCachedImage(
                                  imageUrl: product.imageUrl!,
                                  productId: product.id,
                                  imageStorageKey: product.imagePath,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorIconAsset: shopProductResolvedIcon(
                                    product,
                                  ).asset,
                                  iconSize: 40,
                                ),
                              )
                            : Center(
                                child: ShopProductIconSvg(
                                  asset: shopProductResolvedIcon(product).asset,
                                  size: 40,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.title,
                              style: titleStyle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text('${product.price} монет', style: priceStyle),
                            if (!active) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Сейчас нельзя купить',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kChildInkMuted.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                            if (insufficient) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Нужно ещё ${product.price - balance} монет',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kChildInkMuted.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: onTap,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
                            btnLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: active && !insufficient
                                  ? kChildInk
                                  : kChildInkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
