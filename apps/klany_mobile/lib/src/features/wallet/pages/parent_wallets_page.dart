import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/parent_access_repository.dart';
import '../wallet_repository.dart';

class ParentWalletsPage extends ConsumerWidget {
  const ParentWalletsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(parentFamilyContextProvider);
    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Ошибка: $error')),
      data: (family) {
        if (family == null) return const Center(child: Text('Семья не найдена'));
        return FutureBuilder<List<ParentChildWalletItem>>(
          future: ref.read(walletRepositoryProvider).getFamilyWallets(family.familyId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <ParentChildWalletItem>[];
            return CustomScrollView(
              slivers: [
                const SliverAppBar(pinned: true, title: Text('Кошельки детей')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const CircularProgressIndicator(),
                        ...items.map(
                          (item) => Card(
                            child: ListTile(
                              title: Text(item.displayName),
                              subtitle: Text('Баланс: ${item.balance}'),
                              trailing: TextButton(
                                onPressed: () => _showAdjustDialog(context, ref, item),
                                child: const Text('Корректировка'),
                              ),
                            ),
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
      },
    );
  }

  Future<void> _showAdjustDialog(
    BuildContext context,
    WidgetRef ref,
    ParentChildWalletItem item,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Корректировка: ${item.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сумма (+/-)'),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text.trim());
                if (amount == null) return;
                await ref.read(walletRepositoryProvider).adjustWallet(
                      childId: item.childId,
                      amount: amount,
                      note: noteController.text,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}

