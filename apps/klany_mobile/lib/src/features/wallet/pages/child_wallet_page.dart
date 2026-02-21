import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../wallet_repository.dart';

class ChildWalletPage extends ConsumerWidget {
  const ChildWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) return const Center(child: Text('Сессия ребёнка не найдена'));

    return FutureBuilder<WalletSummary?>(
      future: ref.read(walletRepositoryProvider).getChildWallet(session.childId),
      builder: (context, walletSnap) {
        final wallet = walletSnap.data;
        return CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('Кошелёк')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet),
                        title: const Text('Баланс'),
                        subtitle: Text('${wallet?.balance ?? 0} монет'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (wallet != null)
                      FutureBuilder<List<WalletTxItem>>(
                        future: ref
                            .read(walletRepositoryProvider)
                            .getWalletTransactions(wallet.walletId),
                        builder: (context, txSnap) {
                          final list = txSnap.data ?? const <WalletTxItem>[];
                          if (txSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (list.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('История операций пуста'),
                              ),
                            );
                          }
                          return Column(
                            children: list
                                .map(
                                  (tx) => Card(
                                    child: ListTile(
                                      title: Text('${tx.amount > 0 ? '+' : ''}${tx.amount}'),
                                      subtitle: Text(
                                        '${tx.type} • ${tx.note} • ${DateFormat('dd.MM HH:mm').format(tx.createdAt.toLocal())}',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
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

