import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../quests/quests_repository.dart';
import '../../wallet/pages/child_wallet_page.dart';
import '../../wallet/wallet_repository.dart';
import '../shop_product_icon.dart';
import '../shop_repository.dart';

const _shopCardColors = <Color>[kBrandMint, kBrandSky, kBrandLavender];

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
    final products =
        await ref.read(shopRepositoryProvider).getProducts(_familyId ?? '');
    WalletSummary? wallet;
    int completed = 0;
    if ((_childId ?? '').isNotEmpty) {
      wallet =
          await ref.read(walletRepositoryProvider).getChildWallet(_childId!);
      try {
        final assignments = await ref
            .read(questsRepositoryProvider)
            .getChildAssignments(_childId!);
        completed = assignments.where((a) => a.status == 'completed').length;
      } catch (_) {}
    }
    return _ChildShopData(
      products: products,
      balance: wallet?.balance ?? 0,
      completedCount: completed,
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
        const SnackBar(content: Text('Запрос отправлен, средства заморожены')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
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
        final completed = data?.completedCount ?? 0;

        return Container(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'Магазин наград',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: kChildInk,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        child: InkWell(
                          onTap: _refresh,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.refresh_rounded,
                              color: kChildInk,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ChildProfileCard(
                    completedCount: completed,
                    balance: balance,
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: kChildOutline),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Пока нет доступных товаров',
                          style: TextStyle(
                            color: kChildInkMuted.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ...products.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ChildProductCard(
                            product: e.value,
                            bg: _shopCardColors[e.key % _shopCardColors.length],
                            onBuy: e.value.isActive
                                ? () => _buy(e.value)
                                : () {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
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
        );
      },
    );
  }
}

class _ChildShopData {
  _ChildShopData({
    required this.products,
    required this.balance,
    required this.completedCount,
  });
  final List<ShopProductItem> products;
  final int balance;
  final int completedCount;
}

class _ChildProfileCard extends ConsumerWidget {
  const _ChildProfileCard({
    required this.completedCount,
    required this.balance,
  });
  final int completedCount;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName.trim()
        : 'Участник';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final userKey =
        session != null ? 'child:${session.childId}' : 'child:guest';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ChildWalletPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipOval(
                child: UserAvatar(
                  userKey: userKey,
                  size: 60,
                  fallbackText: initial,
                ),
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
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount ${_taskWord(completedCount)} выполнено',
                      style: const TextStyle(
                        fontSize: 13,
                        color: kChildInkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinStackIcon(size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _formatBalance(balance),
                            style: const TextStyle(
                              fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  static String _formatBalance(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'задачи';
    return 'задач';
  }
}

class _ChildProductCard extends StatelessWidget {
  const _ChildProductCard({
    required this.product,
    required this.bg,
    required this.onBuy,
  });

  final ShopProductItem product;
  final Color bg;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final active = product.isActive;
    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      color: active ? kChildInk : kChildInk.withValues(alpha: 0.45),
    );
    final priceStyle = TextStyle(
      fontSize: 14,
      color: active
          ? kChildInkMuted
          : kChildInkMuted.withValues(alpha: 0.55),
      fontWeight: FontWeight.w600,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onBuy,
        child: Opacity(
          opacity: active ? 1 : 0.72,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: (product.imageUrl ?? '').isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: ShopProductIconSvg(
                                asset: shopProductResolvedIcon(product).asset,
                                size: 40,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: ShopProductIconSvg(
                            asset: shopProductResolvedIcon(product).asset,
                            size: 40,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.price} монет',
                        style: priceStyle,
                      ),
                      if (!active) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Недоступно',
                          style: TextStyle(
                            fontSize: 12,
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
          ),
        ),
      ),
    );
  }
}
