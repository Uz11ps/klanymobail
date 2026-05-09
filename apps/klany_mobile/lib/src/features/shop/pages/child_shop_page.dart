import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../wallet/pages/child_wallet_page.dart';
import '../../wallet/wallet_repository.dart';
import '../shop_repository.dart';

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
    WalletSummary? wallet;
    if ((_childId ?? '').isNotEmpty) {
      wallet = await ref.read(walletRepositoryProvider).getChildWallet(_childId!);
    }
    return _ChildShopData(
      // Don't hide items by isActive on the client side — the backend already
      // returns the products that should be visible to this child. The extra
      // filter caused parents' new items not to appear when isActive was
      // missing/falsy in the response.
      products: products,
      balance: wallet?.balance ?? 0,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _buy(ShopProductItem p) async {
    try {
      await ref.read(shopRepositoryProvider).requestPurchase(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запрос отправлен, средства заморожены'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка покупки: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final childSession = ref.watch(childSessionProvider).asData?.value;
    if (childSession?.familyId != _familyId ||
        childSession?.childId != _childId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fetchAll());
      });
    }

    return FutureBuilder<_ChildShopData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final products = data?.products ?? const <ShopProductItem>[];
        final balance = data?.balance ?? 0;

        return ClanSectionPage(
          title: 'Магазин',
          onRefresh: _refresh,
          onRefreshAsync: _refresh,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _ShopIntroCard(balance: balance),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (snapshot.hasError)
                    ChildSoftCard(
                      child: Text('Ошибка: ${snapshot.error}'),
                    ),
                  if (!snapshot.hasError &&
                      snapshot.connectionState != ConnectionState.waiting &&
                      products.isEmpty)
                    const ChildSoftCard(
                      child: Text(
                        'Пока нет доступных товаров',
                        style: TextStyle(color: kChildInkMuted),
                      ),
                    ),
                  ...products.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ChildProductVisual(
                        product: p,
                        onBuy: () => _buy(p),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildShopData {
  _ChildShopData({required this.products, required this.balance});
  final List<ShopProductItem> products;
  final int balance;
}

class _ShopIntroCard extends ConsumerWidget {
  const _ShopIntroCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName
        : 'Участник';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final userKey = session != null ? 'child:${session.childId}' : 'child:guest';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ChildWalletPage(),
          ),
        ),
        borderRadius: BorderRadius.circular(26),
        child: ChildSoftCard(
          color: kChildSurfaceWhite,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                userKey: userKey,
                size: 60,
                fallbackText: initial,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Копи монеты на награды',
                      style: TextStyle(
                        fontSize: 12,
                        color: kChildInkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinStackIcon(size: 16),
                          const SizedBox(width: 6),
                          Text(
                            balance.toString(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: kChildBrandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: kChildInkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopBalanceCard extends StatelessWidget {
  const _ShopBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      color: kChildSurfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, color: kChildBrandBlue, size: 26),
          const SizedBox(width: 10),
          Text(
            '$balance',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kChildBrandBlue,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '🪙',
            style: TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

String _emojiForProduct(ShopProductItem p) {
  if ((p.imageUrl ?? '').isNotEmpty) return '🛍';
  final desc = '${p.title} ${p.description ?? ''}'.toLowerCase();
  if (desc.contains('игр') || desc.contains('psp') || desc.contains('xbox')) {
    return '🎮';
  }
  if (desc.contains('кино') || desc.contains('фильм')) return '🎬';
  if (desc.contains('книг') || desc.contains('читать')) return '📚';
  if (desc.contains('шокол') || desc.contains('сладк')) return '🍫';
  if (desc.contains('пицц')) return '🍕';
  if (desc.contains('игрушк')) return '🐻';
  if (desc.contains('наушник') || desc.contains('музык')) return '🎧';
  if (desc.contains('мяч') || desc.contains('спорт')) return '🏈';
  if (desc.contains('прогул')) return '🐻';
  return '🎁';
}

class _ChildProductVisual extends StatelessWidget {
  const _ChildProductVisual({required this.product, required this.onBuy});

  final ShopProductItem product;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBuy,
        borderRadius: BorderRadius.circular(26),
        child: ChildSoftCard(
          color: kBrandLavender,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: (product.imageUrl ?? '').isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          product.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            _emojiForProduct(product),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      )
                    : Text(
                        _emojiForProduct(product),
                        style: const TextStyle(fontSize: 28),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.price} монет',
                      style: const TextStyle(
                        fontSize: 14,
                        color: kChildInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: kChildInkMuted,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
