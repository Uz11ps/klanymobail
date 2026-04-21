import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../shop_repository.dart';

class ChildShopPage extends ConsumerStatefulWidget {
  const ChildShopPage({super.key});

  @override
  ConsumerState<ChildShopPage> createState() => _ChildShopPageState();
}

class _ChildShopPageState extends ConsumerState<ChildShopPage> {
  late Future<List<ShopProductItem>> _future;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  void _fetchProducts() {
    final childSession = ref.read(childSessionProvider).asData?.value;
    _familyId = childSession?.familyId;
    _future = ref.read(shopRepositoryProvider).getProducts(_familyId ?? '');
  }

  Future<void> _refresh() async {
    final childSession = ref.read(childSessionProvider).asData?.value;
    final newFuture = ref.read(shopRepositoryProvider).getProducts(childSession?.familyId ?? '');
    setState(() {
      _future = newFuture;
    });
    await newFuture;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild future if familyId changes (login switch)
    final childSession = ref.watch(childSessionProvider).asData?.value;
    if (childSession?.familyId != _familyId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fetchProducts());
      });
    }

    return FutureBuilder<List<ShopProductItem>>(
      future: _future,
      builder: (context, snapshot) {
        final products = (snapshot.data ?? const <ShopProductItem>[])
            .where((p) => p.isActive)
            .toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Магазин'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                    tooltip: 'Обновить',
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator()),
                      if (snapshot.hasError)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Ошибка: ${snapshot.error}'),
                          ),
                        ),
                      ...products.map(
                        (p) => Card(
                          child: ListTile(
                            leading: (p.imageUrl ?? '').isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      p.imageUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.image_not_supported),
                                    ),
                                  )
                                : const Icon(Icons.image),
                            title: Text(p.title),
                            subtitle: Text('${p.price} монет'),
                            trailing: FilledButton(
                              onPressed: () async {
                                try {
                                  await ref.read(shopRepositoryProvider).requestPurchase(p.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Запрос отправлен, средства заморожены'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка покупки: $e')),
                                  );
                                }
                              },
                              child: const Text('Купить'),
                            ),
                          ),
                        ),
                      ),
                      if (!snapshot.hasError &&
                          snapshot.connectionState != ConnectionState.waiting &&
                          products.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Пока нет доступных товаров'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
