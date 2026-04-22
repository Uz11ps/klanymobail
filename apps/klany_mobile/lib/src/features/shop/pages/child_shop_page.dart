import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../home/child_soft_ui.dart';
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
      products: products.where((p) => p.isActive).toList(),
      balance: wallet?.balance ?? 0,
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
        final rubles = balance * 10;

        return ClanSectionPage(
          title: 'Магазин',
          onRefresh: _refresh,
          onRefreshAsync: _refresh,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  const _ShopIntroCard(),
                  const SizedBox(height: 14),
                  _ShopBalanceCard(balance: balance, rubles: rubles),
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

class _ShopIntroCard extends StatelessWidget {
  const _ShopIntroCard();

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kChildBrandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.storefront,
              color: kChildBrandBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Магазин наград',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kChildInk,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Смотри курс обмена и открывай вывод в рубли прямо из магазина.',
                  style: TextStyle(
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
    );
  }
}

class _ShopBalanceCard extends StatelessWidget {
  const _ShopBalanceCard({required this.balance, required this.rubles});

  final int balance;
  final int rubles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4CDF7), width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Баланс: $rubles ₽',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2C2575),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$balance монет доступно • 10 монет = 100 ₽ • 1 монета = 10 ₽',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C2575),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Вывод в рубли станет доступен после обновления сервера.'),
                ),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Конвертация в рубли'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCFC6F2),
              foregroundColor: const Color(0xFF2C2575),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildProductVisual extends StatelessWidget {
  const _ChildProductVisual({required this.product, required this.onBuy});

  final ShopProductItem product;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final rubles = product.price * 10;
    return ChildSoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kChildSurfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: (product.imageUrl ?? '').isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      product.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        color: kChildInkMuted,
                      ),
                    ),
                  )
                : const Icon(Icons.card_giftcard, color: kChildBrandBlue),
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
                if ((product.description ?? '').isNotEmpty)
                  Text(
                    product.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kChildInkMuted,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${product.price} монет • $rubles ₽',
                  style: const TextStyle(
                    fontSize: 13,
                    color: kChildBrandBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onBuy,
            style: FilledButton.styleFrom(
              backgroundColor: kChildBrandBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            child: const Text(
              'Купить',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
