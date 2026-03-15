import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/child_session.dart';
import '../shop_repository.dart';

class ChildShopPage extends ConsumerWidget {
  const ChildShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childSession = ref.watch(childSessionProvider).asData?.value;
    if (childSession == null) return const Center(child: Text('Сессия ребёнка не найдена'));

    return FutureBuilder<List<ShopProductItem>>(
      future: ref.read(shopRepositoryProvider).getProducts(childSession.familyId),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ShopProductItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Магазин')),
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
                    ...products
                        .where((p) => p.isActive)
                        .map(
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
                        products.where((p) => p.isActive).isEmpty)
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
        );
      },
    );
  }
}

