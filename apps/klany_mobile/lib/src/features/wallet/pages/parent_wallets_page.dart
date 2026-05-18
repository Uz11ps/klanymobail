import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/parent_access_repository.dart';
import '../../home/child_soft_ui.dart';
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
                const SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    'Кошельки детей',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kChildInk,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const CircularProgressIndicator(),
                        if (snapshot.hasError)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Ошибка: ${snapshot.error}'),
                            ),
                          ),
                        ...items.map(
                          (item) => Card(
                            child: ListTile(
                              title: Text(item.displayName),
                              subtitle: Text('Баланс: ${item.balance} монет'),
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
    bool isAdding = true;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final modalW = figmaWideModalWidth(context);
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: figmaWideModalInsets(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: modalW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Корректировка: ${item.displayName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kChildInk,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    isAdding ? Colors.green : null,
                                foregroundColor:
                                    isAdding ? Colors.white : Colors.green,
                                side: const BorderSide(color: Colors.green),
                              ),
                              onPressed: () => setState(() => isAdding = true),
                              child: const Text('+ Начислить'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    !isAdding ? Colors.red : null,
                                foregroundColor:
                                    !isAdding ? Colors.white : Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () => setState(() => isAdding = false),
                              child: const Text('− Списать'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Сумма (монет)',
                          prefixText: isAdding ? '+' : '−',
                          prefixStyle: TextStyle(
                            color: isAdding ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        decoration:
                            const InputDecoration(labelText: 'Комментарий'),
                      ),
                      const SizedBox(height: 20),
                      FigmaDialogActionStack(
                        onCancel: () => Navigator.pop(dialogCtx),
                        onConfirm: () async {
                          final raw =
                              int.tryParse(amountController.text.trim());
                          if (raw == null || raw <= 0) return;
                          final amount = isAdding ? raw : -raw;
                          await ref.read(walletRepositoryProvider).adjustWallet(
                                childId: item.childId,
                                amount: amount,
                                note: noteController.text,
                              );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

