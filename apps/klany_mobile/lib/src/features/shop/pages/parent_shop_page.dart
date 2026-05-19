import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../shop_repository.dart';
import '../shop_product_icon.dart';
import '../../../core/app_snackbar.dart';

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
        if (family == null) {
          return const Center(child: Text('Семья не найдена'));
        }
        final pages = <Widget>[
          _ParentProductsList(familyId: family.familyId),
          _ParentCreateProductForm(familyId: family.familyId),
          _ParentPurchasesQueue(familyId: family.familyId),
        ];
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ref.read(shopRepositoryProvider).getProducts(widget.familyId);
  }

  @override
  void didUpdateWidget(_ParentProductsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      _future = ref.read(shopRepositoryProvider).getProducts(widget.familyId);
    }
  }

  Future<void> _reload() async {
    final future = ref
        .read(shopRepositoryProvider)
        .getProducts(widget.familyId);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _editProduct(ShopProductItem p) async {
    final titleCtl = TextEditingController(text: p.title);
    final descCtl = TextEditingController(
      text: shopProductDescriptionWithoutIconMarker(p.description),
    );
    final priceCtl = TextEditingController(text: p.price.toString());
    var isActive = p.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(ctx).width * 0.10,
            vertical: 24,
          ),
          title: const Text('Редактировать товар'),
          content: SizedBox(
            width: double.maxFinite,
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
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Цена'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: const Text('Активен'),
                    onChanged: (v) => setLocalState(() => isActive = v),
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
    if (ok != true) return;
    final price = int.tryParse(priceCtl.text.trim());
    if (price == null || price <= 0) {
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Цена должна быть > 0')),
      );
      return;
    }
    final storedDescription = composeShopProductDescription(
      iconId: shopProductIconIdFromDescription(p.description),
      userDescription: descCtl.text.trim(),
    );
    await ref
        .read(shopRepositoryProvider)
        .updateProduct(
          productId: p.id,
          title: titleCtl.text.trim(),
          description: storedDescription,
          price: price,
          isActive: isActive,
        );
    if (!mounted) return;
    _reload();
    context.showKlanySnackBar(const SnackBar(content: Text('Товар обновлён')));
  }

  Future<void> _deleteProduct(ShopProductItem p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Удалить товар с витрины?'),
            const SizedBox(height: 16),
            FigmaDialogActionStack(
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
              confirmLabel: 'Удалить',
              confirmGradient:
                  FigmaDialogActionStack.destructiveGradientVertical,
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await ref.read(shopRepositoryProvider).deleteProduct(p.id);
    if (!mounted) return;
    _reload();
    context.showKlanySnackBar(const SnackBar(content: Text('Товар удалён')));
  }

  Future<void> _showProductActions(ShopProductItem p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: kChildSurfaceWhite,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: kChildInk),
              title: const Text('Редактировать'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(
                p.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: kChildInk,
              ),
              title: Text(p.isActive ? 'Деактивировать' : 'Активировать'),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFD83A3A),
              ),
              title: const Text('Удалить'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _editProduct(p);
    } else if (action == 'toggle') {
      await ref.read(shopRepositoryProvider).toggleProduct(p.id, !p.isActive);
      if (!mounted) return;
      _reload();
      context.showKlanySnackBar(
        const SnackBar(content: Text('Статус товара обновлён')),
      );
    } else if (action == 'delete') {
      await _deleteProduct(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopProductItem>>(
      future: _future,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ShopProductItem>[];
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(19, 34, 19, 104),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 48,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 22),
                    const Expanded(
                      child: Text(
                        'Магазин товаров',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 29),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
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
                  (p) => _FigmaProductCard(
                    product: p,
                    onTap: () => _showProductActions(p),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FigmaProductCard extends StatelessWidget {
  const _FigmaProductCard({required this.product, required this.onTap});

  final ShopProductItem product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = product.isActive
        ? Colors.black
        : Colors.black.withValues(alpha: 0.45);
    final iconAsset = shopProductResolvedIcon(product).asset;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 118,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CBF7),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD8CBF7).withValues(alpha: 0.35),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: const Color(0xFFB3A5D3).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 13),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.18),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  height: 86,
                  child: Center(
                    child: (product.imageUrl ?? '').isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              product.imageUrl!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  ShopProductIconSvg(
                                    asset: iconAsset,
                                    size: 76,
                                  ),
                            ),
                          )
                        : ShopProductIconSvg(asset: iconAsset, size: 76),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title.trim().isEmpty
                            ? 'Без названия'
                            : product.title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          height: 0.92,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            color: titleColor,
                            height: 1.0,
                          ),
                          children: [
                            TextSpan(
                              text: '${product.price} монет ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '(${product.price * 10} ₽)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
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
      ),
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
  String? _selectedIconId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (price == null || price <= 0 || _title.text.trim().isEmpty) {
      context.showKlanySnackBar(
        const SnackBar(content: Text('Введите название и цену')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final rawDescription = _description.text.trim();
      final description = composeShopProductDescription(
        iconId: _selectedIconId,
        userDescription: rawDescription,
      );
      await ref
          .read(shopRepositoryProvider)
          .createProduct(
            title: _title.text.trim(),
            description: description,
            price: price,
            imageFile: _file,
          );
      if (!mounted) return;
      context.showKlanySnackBar(
        const SnackBar(content: Text('Товар добавлен')),
      );
      _title.clear();
      _description.clear();
      _price.text = '100';
      setState(() {
        _file = null;
        _selectedIconId = null;
      });
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка добавления: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _figmaFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Nunito',
        color: Colors.black.withValues(alpha: 0.10),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(62),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(62),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(62),
        borderSide: const BorderSide(color: kChildBrandBlue, width: 1.4),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(19, 34, 19, 112),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 48,
                ),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 22),
              const Expanded(
                child: Text(
                  'Добавить товар',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 29),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 30, 10, 30),
            decoration: BoxDecoration(
              color: const Color(0xFFC1D8F5),
              borderRadius: BorderRadius.circular(46),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC1DCFF).withValues(alpha: 0.35),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: const Color(0xFFBFD9FF).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(46),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.20),
                ],
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Выбрать фото',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFF2B88FF),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _busy
                        ? null
                        : () async {
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 84,
                            );
                            setState(() {
                              _file = file;
                              _selectedIconId = null;
                            });
                          },
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Icon(
                        _file != null ? Icons.check : Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: _file != null ? 34 : 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Или выберите иконку товара',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 21),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: kShopProductIconOptions.map((option) {
                    final selected = _selectedIconId == option.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIconId = selected ? null : option.id;
                          if (!selected) _file = null;
                        });
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(
                                      0xFF4C77AD,
                                    ).withValues(alpha: 0.23)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF3F3F3F),
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: ShopProductIconSvg(
                              asset: option.asset,
                              size: 32,
                            ),
                          ),
                          if (selected)
                            Positioned(
                              top: -15,
                              right: -4,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF80AB57),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          _fieldLabel('Название товара'),
          TextField(
            controller: _title,
            decoration: _figmaFieldDecoration('велосипед'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Описание'),
          TextField(
            controller: _description,
            decoration: _figmaFieldDecoration(
              'Лёгкий и быстрый, для прогул...',
            ),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Цена (монеты)'),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: _figmaFieldDecoration('1111'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD9F6C2),
              borderRadius: BorderRadius.circular(62),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6F7D9).withValues(alpha: 0.35),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: const Color(0xFFD4FFB3).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 13),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(62),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _busy ? null : _save,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text(
                          'Сохранить товар',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            height: 1.0,
                          ),
                        ),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ref
        .read(shopRepositoryProvider)
        .getPendingPurchases(widget.familyId);
  }

  @override
  void didUpdateWidget(_ParentPurchasesQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      _future = ref
          .read(shopRepositoryProvider)
          .getPendingPurchases(widget.familyId);
    }
  }

  Future<void> _reload() async {
    final future = ref
        .read(shopRepositoryProvider)
        .getPendingPurchases(widget.familyId);
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopPurchaseItem>>(
      future: _future,
      builder: (context, snapshot) {
        final purchases = snapshot.data ?? const <ShopPurchaseItem>[];
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(19, 34, 19, 104),
              children: [
                SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 48,
                          ),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 30,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const Text(
                        'Запросы',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                  (p) => _PurchaseCard(
                    item: p,
                    onDecide: (approve) async {
                      await ref
                          .read(shopRepositoryProvider)
                          .decidePurchase(p.id, approve);
                      if (mounted) await _reload();
                      if (context.mounted) {
                        context.showKlanySnackBar(
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
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.04),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  SizedBox(
                    width: 73,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          userKey: 'child:${item.childName}',
                          size: 73,
                          fallbackText: initial,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.childName.trim().isEmpty
                              ? 'Ребёнок'
                              : item.childName.trim(),
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.productTitle.trim().isEmpty
                              ? 'Без названия'
                              : item.productTitle.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                offset: const Offset(0, 4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${item.totalPrice} монет (${item.totalPrice * 10} ₽)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                offset: const Offset(0, 4),
                                blurRadius: 4,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _PurchaseDecisionButton(
                      label: 'Отклонить',
                      color: const Color(0xFFFFC4C4),
                      shadowColor: const Color(0xFFFAC0C0),
                      onTap: () => onDecide(false),
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: _PurchaseDecisionButton(
                      label: 'Подтвердить',
                      color: const Color(0xFFD9F6C2),
                      shadowColor: const Color(0xFFE6F7D9),
                      onTap: () => onDecide(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDecisionButton extends StatelessWidget {
  const _PurchaseDecisionButton({
    required this.label,
    required this.color,
    required this.shadowColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(41),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 13),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(41),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                height: 1.0,
              ),
            ),
          ),
        ),
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      height: 76 + 16 + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 278,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(45),
                      border: Border.all(color: const Color(0xFF22459E)),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(
                        child: _ShopNavBtn(
                          icon: Icons.format_list_bulleted,
                          selected: currentIndex == 0,
                          big: currentIndex == 0,
                          onTap: () => onSelected(0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(
                        child: _ShopNavBtn(
                          icon: Icons.add,
                          selected: currentIndex == 1,
                          big: currentIndex == 1,
                          onTap: () => onSelected(1),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(
                        child: _ShopNavBtn(
                          icon: Icons.shopping_bag_outlined,
                          selected: currentIndex == 2,
                          big: currentIndex == 2,
                          onTap: () => onSelected(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
