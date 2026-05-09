import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../shop_repository.dart';

const _kProductEmojis = [
  '🎮', '🐻', '📚', '🎧', '🏈', '🎁',
  '🍫', '🚲', '🍕', '⚽', '🎬', '🎨',
];

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
  return '🎁';
}

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
        if (family == null)
          return const Center(child: Text('Семья не найдена'));
        final pages = <Widget>[
          _ParentProductsList(familyId: family.familyId),
          _ParentCreateProductForm(familyId: family.familyId),
          _ParentPurchasesQueue(familyId: family.familyId),
        ];
        return Scaffold(
          body: pages[_tab],
          bottomNavigationBar: _ShopBottomBar(
            currentIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
        );
      },
    );
  }
}

class _ParentProductsList extends ConsumerStatefulWidget {
  const _ParentProductsList({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ParentProductsList> createState() =>
      _ParentProductsListState();
}

class _ParentProductsListState extends ConsumerState<_ParentProductsList> {
  Future<List<ShopProductItem>>? _future;

  void _reload() {
    setState(() {
      _future = ref.read(shopRepositoryProvider).getProducts(widget.familyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopProductItem>>(
      future:
          _future ??
          ref.read(shopRepositoryProvider).getProducts(widget.familyId),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ShopProductItem>[];
        return Scaffold(
          backgroundColor: kBgCloud,
          appBar: AppBar(
            backgroundColor: kBgCloud,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kChildInk),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            centerTitle: true,
            title: const Text(
              'Магазин товаров',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kChildInk,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Обновить',
                onPressed: _reload,
                icon: const Icon(Icons.refresh, color: kChildInk),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
              if (snapshot.hasError)
                ChildSoftCard(
                  color: kBrandRose,
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка: ${snapshot.error}'),
                ),
              if (products.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                ChildSoftCard(
                  color: kBrandLavender,
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Товаров пока нет — добавь первый!',
                    style: TextStyle(color: kChildInk, fontSize: 14),
                  ),
                ),
              ...products.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChildSoftCard(
                    color: p.isActive ? kBrandLavender : kBrandSky,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: (p.imageUrl ?? '').isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  p.imageUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    _emojiForProduct(p),
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              )
                            : Text(
                                _emojiForProduct(p),
                                style: const TextStyle(fontSize: 28),
                              ),
                      ),
                      title: Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${p.price} монет (${p.price * 10} ₽)',
                        style: const TextStyle(
                          color: kChildInkMuted,
                          fontSize: 13,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'toggle') {
                                await ref
                                    .read(shopRepositoryProvider)
                                    .toggleProduct(p.id, !p.isActive);
                                if (!context.mounted) return;
                                _reload();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Статус товара обновлён'),
                                  ),
                                );
                              }
                              if (value == 'edit') {
                                final titleCtl = TextEditingController(
                                  text: p.title,
                                );
                                final descCtl = TextEditingController(
                                  text: p.description ?? '',
                                );
                                final priceCtl = TextEditingController(
                                  text: p.price.toString(),
                                );
                                var isActive = p.isActive;
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setLocalState) =>
                                        AlertDialog(
                                          title: const Text(
                                            'Редактировать товар',
                                          ),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: titleCtl,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Название',
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: descCtl,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Описание',
                                                      ),
                                                  maxLines: 3,
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: priceCtl,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Цена',
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  value: isActive,
                                                  title: const Text('Активен'),
                                                  onChanged: (v) =>
                                                      setLocalState(
                                                        () => isActive = v,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Отмена'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Сохранить'),
                                            ),
                                          ],
                                        ),
                                  ),
                                );
                                if (ok == true) {
                                  final price = int.tryParse(
                                    priceCtl.text.trim(),
                                  );
                                  if (price == null || price <= 0) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Цена должна быть > 0'),
                                      ),
                                    );
                                    return;
                                  }
                                  await ref
                                      .read(shopRepositoryProvider)
                                      .updateProduct(
                                        productId: p.id,
                                        title: titleCtl.text.trim(),
                                        description: descCtl.text.trim(),
                                        price: price,
                                        isActive: isActive,
                                      );
                                  if (!context.mounted) return;
                                  _reload();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Товар обновлён'),
                                    ),
                                  );
                                }
                              }
                              if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Удалить товар'),
                                    content: const Text(
                                      'Удалить товар с витрины?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Отмена'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(shopRepositoryProvider)
                                      .deleteProduct(p.id);
                                  if (!context.mounted) return;
                                  _reload();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Товар удалён'),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  p.isActive
                                      ? 'Деактивировать'
                                      : 'Активировать',
                                ),
                              ),
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
                        ),
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

class _ParentCreateProductForm extends ConsumerStatefulWidget {
  const _ParentCreateProductForm({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ParentCreateProductForm> createState() =>
      _ParentCreateProductFormState();
}

class _ParentCreateProductFormState
    extends ConsumerState<_ParentCreateProductForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '100');
  final _picker = ImagePicker();
  XFile? _file;
  String? _selectedEmoji;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  InputDecoration _softField(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kChildInkMuted, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCloud,
      appBar: AppBar(
        backgroundColor: kBgCloud,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kChildInk),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Добавить товар',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kChildInk,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Photo / emoji picker
          ChildSoftCard(
            color: kBrandSky,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Выбрать фото',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _busy
                      ? null
                      : () async {
                          final file = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 84,
                          );
                          setState(() {
                            _file = file;
                            _selectedEmoji = null;
                          });
                        },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: kChildBrandBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _file != null
                        ? const Icon(Icons.check, color: Colors.white, size: 32)
                        : const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Или выберите иконку товара',
                  style: TextStyle(
                    fontSize: 13,
                    color: kChildInkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: _kProductEmojis.map((e) {
                    final selected = _selectedEmoji == e;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = selected ? null : e;
                          if (!selected) _file = null;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: selected
                              ? Border.all(color: kChildBrandBlue, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(e,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              'Название товара',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kChildInk,
              ),
            ),
          ),
          TextField(
            controller: _title,
            decoration: _softField('велосипед'),
            style: const TextStyle(fontSize: 15, color: kChildInk),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              'Описание',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kChildInk,
              ),
            ),
          ),
          TextField(
            controller: _description,
            decoration:
                _softField('Лёгкий и быстрый, для прогулок'),
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: kChildInk),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              'Цена (монеты)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kChildInk,
              ),
            ),
          ),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: _softField('100'),
            style: const TextStyle(fontSize: 15, color: kChildInk),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final price = int.tryParse(_price.text.trim());
                      if (price == null || _title.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Введите название и цену'),
                          ),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      try {
                        await ref
                            .read(shopRepositoryProvider)
                            .createProduct(
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
                        setState(() {
                          _file = null;
                          _selectedEmoji = null;
                        });
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка добавления: $e'),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: kBrandMint,
                foregroundColor: const Color(0xFF1F4F1B),
                minimumSize: const Size.fromHeight(54),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Сохранить товар',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentPurchasesQueue extends ConsumerStatefulWidget {
  const _ParentPurchasesQueue({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ParentPurchasesQueue> createState() =>
      _ParentPurchasesQueueState();
}

class _ParentPurchasesQueueState extends ConsumerState<_ParentPurchasesQueue> {
  Future<List<ShopPurchaseItem>>? _future;

  void _reload() {
    setState(() {
      _future = ref
          .read(shopRepositoryProvider)
          .getPendingPurchases(widget.familyId);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopPurchaseItem>>(
      future:
          _future ??
          ref.read(shopRepositoryProvider).getPendingPurchases(widget.familyId),
      builder: (context, snapshot) {
        final purchases = snapshot.data ?? const <ShopPurchaseItem>[];
        return Scaffold(
          backgroundColor: kBgCloud,
          appBar: AppBar(
            backgroundColor: kBgCloud,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kChildInk),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            centerTitle: true,
            title: const Text(
              'Запросы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kChildInk,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (snapshot.hasError)
                ChildSoftCard(
                  color: kBrandRose,
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка: ${snapshot.error}'),
                ),
              if (purchases.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Нет запросов на покупку',
                      style: TextStyle(color: kChildInkMuted, fontSize: 15),
                    ),
                  ),
                ),
              ...purchases.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PurchaseCard(
                    item: p,
                    onDecide: (approve) async {
                      await ref
                          .read(shopRepositoryProvider)
                          .decidePurchase(p.id, approve);
                      if (mounted) _reload();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              approve
                                  ? 'Покупка подтверждена'
                                  : 'Покупка отклонена',
                            ),
                          ),
                        );
                      }
                    },
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

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.item, required this.onDecide});
  final ShopPurchaseItem item;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context) {
    final initial = item.childName.trim().isNotEmpty
        ? item.childName.trim()[0].toUpperCase()
        : '?';
    return ChildSoftCard(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                userKey: 'child:${item.childName}',
                size: 48,
                fallbackText: initial,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kChildInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.totalPrice} монет (${item.totalPrice * 10} ₽)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kChildInkMuted,
                      ),
                    ),
                    Text(
                      item.childName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kChildInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => onDecide(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandRose,
                    foregroundColor: const Color(0xFF8B2C36),
                    minimumSize: const Size.fromHeight(44),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Отклонить',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => onDecide(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandMint,
                    foregroundColor: const Color(0xFF1F4F1B),
                    minimumSize: const Size.fromHeight(44),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Подтвердить',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopBottomBar extends StatelessWidget {
  const _ShopBottomBar({required this.currentIndex, required this.onSelected});
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ShopNavBtn(
                    icon: Icons.format_list_bulleted,
                    selected: currentIndex == 0,
                    big: currentIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _ShopNavBtn(
                    icon: Icons.add,
                    selected: currentIndex == 1,
                    big: currentIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _ShopNavBtn(
                    icon: Icons.shopping_bag_outlined,
                    selected: currentIndex == 2,
                    big: currentIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopNavBtn extends StatelessWidget {
  const _ShopNavBtn({
    required this.icon,
    required this.selected,
    required this.big,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (big) {
      return Material(
        color: kChildBrandBlue,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: kChildBrandBlue.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ),
      );
    }
    return Material(
      color: selected
          ? kChildBrandBlue.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: 24,
            color: selected ? kChildBrandBlue : kChildInkMuted,
          ),
        ),
      ),
    );
  }
}
