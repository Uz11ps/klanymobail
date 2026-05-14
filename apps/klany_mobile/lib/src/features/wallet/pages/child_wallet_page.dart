import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../../home/avatar_store.dart';
import '../../home/child_soft_ui.dart';
import '../../quests/quests_repository.dart';
import '../wallet_repository.dart';

String _formatNumber(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

class ChildWalletPage extends ConsumerWidget {
  const ChildWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Сессия ребёнка не найдена')),
      );
    }

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
        titleSpacing: 0,
        title: const Text(
          'Кошелёк',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
      ),
      body: FutureBuilder<WalletSummary?>(
        future: ref
            .read(walletRepositoryProvider)
            .getChildWallet(session.childId),
        builder: (context, walletSnap) {
          final wallet = walletSnap.data;
          final balance = wallet?.balance ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const SizedBox(height: 4),
              _ChildWalletProfileCard(balance: balance),
              const SizedBox(height: 18),
              Container(height: 1, color: kChildOutline),
              const SizedBox(height: 18),
              _WithdrawCard(balance: balance),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Лента операций',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
              ),
              if (walletSnap.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (walletSnap.hasError)
                ChildSoftCard(
                  color: kBrandRose,
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка: ${walletSnap.error}'),
                ),
              if (wallet != null)
                FutureBuilder<List<WalletTxItem>>(
                  future: ref
                      .read(walletRepositoryProvider)
                      .getWalletTransactions(wallet.walletId),
                  builder: (context, txSnap) {
                    final list = txSnap.data ?? const <WalletTxItem>[];
                    if (txSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Лента пока пуста',
                            style: TextStyle(
                              color: kChildInkMuted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }
                    return _GroupedTxList(items: list);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.balance});
  final String name;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return ChildSoftCard(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kBrandMint,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F4F1B),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.trim().isEmpty ? 'Участник' : name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '$balance',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kChildBrandBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawCard extends StatelessWidget {
  const _WithdrawCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return ChildSoftCard(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Вывод на карту',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kChildInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '10 монет = 100 ₽',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: kChildInkMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: kChildOutline),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Вывод средств скоро будет доступен'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: kBrandSky,
              foregroundColor: kChildInk,
              minimumSize: const Size.fromHeight(50),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Вывести',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedTxList extends StatelessWidget {
  const _GroupedTxList({required this.items});
  final List<WalletTxItem> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<WalletTxItem>>{};
    for (final tx in items) {
      final d = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
      String label;
      if (d == today) {
        label = 'Сегодня';
      } else if (d == yesterday) {
        label = 'Вчера';
      } else {
        label = DateFormat('dd.MM').format(tx.createdAt);
      }
      grouped.putIfAbsent(label, () => []).add(tx);
    }

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kChildInkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...entry.value.map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TxRow(tx: tx),
              )),
        ],
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final WalletTxItem tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    return ChildSoftCard(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note.isNotEmpty ? tx.note : _typeLabel(tx.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(tx),
                  style: const TextStyle(
                    fontSize: 12,
                    color: kChildInkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${tx.amount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: positive
                      ? const Color(0xFF18B26B)
                      : const Color(0xFFD83A3A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(tx.createdAt.toLocal()),
                style: const TextStyle(
                  fontSize: 11,
                  color: kChildInkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'reward':
        return 'Награда';
      case 'purchase':
        return 'Покупка';
      case 'adjust':
        return 'Корректировка';
      default:
        return 'Операция';
    }
  }

  String _statusLabel(WalletTxItem tx) {
    if (tx.type == 'purchase') return 'Покупка';
    if (tx.type == 'adjust') return 'Корректировка';
    return 'Выполнено';
  }
}

class _ChildWalletProfileCard extends ConsumerWidget {
  const _ChildWalletProfileCard({required this.balance});
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

    return FutureBuilder<List<ChildQuestAssignmentItem>>(
      future: session == null
          ? Future.value(const <ChildQuestAssignmentItem>[])
          : ref
              .read(questsRepositoryProvider)
              .getChildAssignments(session.childId),
      builder: (context, snap) {
        final completed = (snap.data ?? const <ChildQuestAssignmentItem>[])
            .where((a) => a.status == 'completed')
            .length;
        return Container(
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
                      '$completed ${_taskWord(completed)} выполнено',
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
                            _formatNumber(balance),
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
        );
      },
    );
  }

  static String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'задачи';
    return 'задач';
  }
}
