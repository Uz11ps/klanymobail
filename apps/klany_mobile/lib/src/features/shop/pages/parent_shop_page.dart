import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/parent_access_repository.dart';
import '../shop_repository.dart';

class ParentShopPage extends ConsumerStatefulWidget {
  const ParentShopPage({super.key});

  @override
  ConsumerState<ParentShopPage> createState() => _ParentShopPageState();
}

class _ParentShopPageState extends ConsumerState<ParentShopPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));
        final pages = <Widget>[
          _ParentProductsList(familyId: family.familyId),
          _ParentCreateProductForm(familyId: family.familyId),
          _ParentPurchasesQueue(familyId: family.familyId),
        ];
        return Scaffold(
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.store), label: 'Товары'),
              NavigationDestination(icon: Icon(Icons.add_box), label: 'Добавить'),
              NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Запросы'),
            ],
          ),
        );
      },
    );
  }
}

class _ParentProductsList extends ConsumerWidget {
  const _ParentProductsList({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ShopProductItem>>(
      future: ref.read(shopRepositoryProvider).getProducts(familyId),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ShopProductItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Магазин: товары')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: products
                      .map(
                        (p) => Card(
                          child: SwitchListTile(
                            title: Text(p.title),
                            subtitle: Text('${p.price} монет'),
                            value: p.isActive,
                            onChanged: (v) async {
                              await ref.read(shopRepositoryProvider).toggleProduct(p.id, v);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Статус товара обновлён')),
                                );
                              }
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParentCreateProductForm extends ConsumerStatefulWidget {
  const _ParentCreateProductForm({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ParentCreateProductForm> createState() =>
      _ParentCreateProductFormState();
}

class _ParentCreateProductFormState extends ConsumerState<_ParentCreateProductForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '100');
  final _picker = ImagePicker();
  XFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Добавить товар')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Название товара'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Цена (монеты)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final file = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 84,
                          );
                          setState(() => _file = file);
                        },
                  icon: const Icon(Icons.photo),
                  label: Text(_file == null ? 'Выбрать фото' : 'Фото выбрано'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final price = int.tryParse(_price.text.trim());
                            if (price == null || _title.text.trim().isEmpty) return;
                            setState(() => _busy = true);
                            try {
                              await ref.read(shopRepositoryProvider).createProduct(
                                    title: _title.text,
                                    description: _description.text,
                                    price: price,
                                    imageFile: _file,
                                  );
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Товар добавлен')),
                              );
                              _title.clear();
                              _description.clear();
                              _price.text = '100';
                              setState(() => _file = null);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text('Ошибка добавления: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Сохранить товар'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentPurchasesQueue extends ConsumerWidget {
  const _ParentPurchasesQueue({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ShopPurchaseItem>>(
      future: ref.read(shopRepositoryProvider).getPendingPurchases(familyId),
      builder: (context, snapshot) {
        final purchases = snapshot.data ?? const <ShopPurchaseItem>[];
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Запросы на покупку')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: purchases
                      .map(
                        (p) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.productTitle} • ${p.totalPrice} монет'),
                                Text('Ребёнок: ${p.childName}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await ref
                                              .read(shopRepositoryProvider)
                                              .decidePurchase(p.id, false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Покупка отклонена')),
                                            );
                                          }
                                        },
                                        child: const Text('Отклонить'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () async {
                                          await ref
                                              .read(shopRepositoryProvider)
                                              .decidePurchase(p.id, true);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Покупка подтверждена')),
                                            );
                                          }
                                        },
                                        child: const Text('Подтвердить'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

