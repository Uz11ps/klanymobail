import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/child_session.dart';
import '../../home/child_dashboard_profile_card.dart';
import '../../home/child_soft_ui.dart';
import '../wallet_repository.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/value_bump.dart';

/// Зелёный / красный сумм в ленте — как в Figma (node 0:522).
const _kTxGreen = Color(0xFF6FFF00);
const _kTxRed = Color(0xFFE35254);

/// Градиент кнопки «Вывести» (sky).
const _kWithdrawButtonTop = Color(0xFFC1D8F5);
const _kWithdrawShadowBlue = Color.fromRGBO(193, 220, 255, 0.35);

String _formatNumber(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

Widget _walletDividerLine() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = math.min(
        constraints.maxWidth,
        constraints.maxWidth * (311 / 353),
      );
      return Center(
        child: SizedBox(
          width: w,
          height: 1,
          child: Image.asset(
            'assets/figma/child_dashboard_divider.png',
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Подписи времени как в макете: «сейчас», «N мин назад», «N часа назад», «вчера».
String _relativeTxTime(DateTime at, DateTime now) {
  final local = at.toLocal();
  final n = now.toLocal();
  var diff = n.difference(local);
  if (diff.isNegative) diff = Duration.zero;

  final today = DateTime(n.year, n.month, n.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(local.year, local.month, local.day);

  if (d == yesterday) {
    return 'вчера';
  }

  if (d != today) {
    return DateFormat('dd.MM.yy').format(local);
  }

  if (diff.inMinutes < 2) return 'сейчас';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  final h = diff.inHours;
  if (h < 24) {
    return '$h ${_hourRu(h)} назад';
  }
  return DateFormat('HH:mm').format(local);
}

String _hourRu(int h) {
  final m10 = h % 10;
  final m100 = h % 100;
  if (m100 >= 11 && m100 <= 14) return 'часов';
  if (m10 == 1) return 'час';
  if (m10 >= 2 && m10 <= 4) return 'часа';
  return 'часов';
}

class ChildWalletPage extends ConsumerStatefulWidget {
  const ChildWalletPage({super.key});

  @override
  ConsumerState<ChildWalletPage> createState() => _ChildWalletPageState();
}

class _ChildWalletPageState extends ConsumerState<ChildWalletPage>
    with WidgetsBindingObserver {
  String? _memoChildId;
  Future<WalletSummary?>? _walletFuture;
  String? _memoWalletIdForTx;
  Future<List<WalletTxItem>>? _txFuture;
  Timer? _livePoll;

  void _startLivePollIfNeeded() {
    _livePoll ??= Timer.periodic(kChildLivePollInterval, (_) {
      _reloadWallet(silent: true);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLivePollIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _livePoll?.cancel();
      _livePoll = null;
    } else if (state == AppLifecycleState.resumed) {
      _startLivePollIfNeeded();
      Future<void>.microtask(() => _reloadWallet(silent: true));
    }
  }

  void _reloadWallet({bool silent = false}) {
    final session = ref.read(childSessionProvider).asData?.value;
    final childId = session?.childId;
    if (childId == null || childId.isEmpty) return;
    final next = ref.read(walletRepositoryProvider).getChildWallet(childId);
    setState(() {
      _memoChildId = childId;
      _walletFuture = next;
    });
    next.then((wallet) {
      if (!mounted || wallet == null) return;
      if (_memoWalletIdForTx != wallet.walletId) {
        setState(() {
          _memoWalletIdForTx = wallet.walletId;
          _txFuture = ref
              .read(walletRepositoryProvider)
              .getWalletTransactions(wallet.walletId);
        });
      }
    });
  }

  Future<WalletSummary?> _walletFutureFor(String childId) {
    if (_memoChildId != childId) {
      _memoChildId = childId;
      _walletFuture =
          ref.read(walletRepositoryProvider).getChildWallet(childId);
      _memoWalletIdForTx = null;
      _txFuture = null;
    }
    return _walletFuture!;
  }

  Future<List<WalletTxItem>> _txFutureFor(String walletId) {
    if (_memoWalletIdForTx != walletId) {
      _memoWalletIdForTx = walletId;
      _txFuture =
          ref.read(walletRepositoryProvider).getWalletTransactions(walletId);
    }
    return _txFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Сессия ребёнка не найдена')),
      );
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final cw = kFigmaChildDashboardContentWidth(screenW);
    final hPad = kFigmaChildDashboardHorizontalPadding(screenW, cw);
    final bottomPad = ChildBottomClanBar.scrollBottomClearance(context) + 28;

    return FutureBuilder<WalletSummary?>(
      future: _walletFutureFor(session.childId),
      builder: (context, walletSnap) {
        final wallet = walletSnap.data;
        final balance = wallet?.balance ?? 0;
        final completed = wallet?.completedQuestsCount ?? 0;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/figma/child_dashboard_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: kBgCloud.withValues(alpha: 0.35)),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xFFF5F7FB).withValues(alpha: 0.66),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(hPad, 26, hPad, bottomPad),
                    children: [
                      SizedBox(
                        width: cw,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.of(context).maybePop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.arrow_back,
                                    size: 24,
                                    color: kChildInk,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: Text(
                                'Кошелек',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WalletProfileBlock(
                        balance: balance,
                        completedCount: completed,
                      ),
                      const SizedBox(height: 20),
                      _walletDividerLine(),
                      const SizedBox(height: 20),
                      _WithdrawFigmaCard(),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Лента операций',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (walletSnap.connectionState ==
                          ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (walletSnap.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Ошибка: ${walletSnap.error}',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFFE35254),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (wallet != null)
                        FutureBuilder<List<WalletTxItem>>(
                          future: _txFutureFor(wallet.walletId),
                          builder: (context, txSnap) {
                            final list =
                                txSnap.data ?? const <WalletTxItem>[];
                            if (txSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (list.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    'Лента пока пуста',
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: kChildInkMuted,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _GroupedTxList(items: list);
                          },
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

class _WalletProfileBlock extends StatelessWidget {
  const _WalletProfileBlock({
    required this.balance,
    required this.completedCount,
  });

  final int balance;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final session = ref.watch(childSessionProvider).asData?.value;
        final name = session?.childDisplayName.trim().isNotEmpty == true
            ? session!.childDisplayName.trim()
            : 'Участник';
        if (session == null) {
          return const SizedBox.shrink();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ChildDashboardAvatar(
                  session: session,
                  displayName: name,
                  size: 107,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$completedCount ${_taskWord(completedCount)} выполнено',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: kFigmaChildBalancePill,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FigmaProfileCoinStack(
                                width: 18,
                                height: 17,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatNumber(balance),
                                style: GoogleFonts.nunito(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: kFigmaChildScreenBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _taskWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'задача';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'задачи';
    }
    return 'задач';
  }
}

class _WithdrawFigmaCard extends StatelessWidget {
  const _WithdrawFigmaCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Вывод на карту',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '10 монет = 100 ₽',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            _walletDividerLine(),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(62),
                gradient: const LinearGradient(
                  colors: [_kWithdrawButtonTop, _kWithdrawButtonTop],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kWithdrawShadowBlue,
                    blurRadius: 50,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: _kWithdrawShadowBlue,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(62),
                  onTap: () {
                    context.showKlanySnackBar(
                      const SnackBar(
                        content: Text(
                          'Вывод средств скоро будет доступен',
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: Text(
                        'Вывести',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        label = DateFormat('dd.MM.yyyy').format(tx.createdAt);
      }
      grouped.putIfAbsent(label, () => []).add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              entry.key,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
          ...entry.value.map(
            (tx) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TxFigmaCard(tx: tx, now: now),
            ),
          ),
        ],
      ],
    );
  }
}

class _TxFigmaCard extends StatelessWidget {
  const _TxFigmaCard({required this.tx, required this.now});

  final WalletTxItem tx;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    final amountStyle = GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: positive ? _kTxGreen : _kTxRed,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    tx.note.isNotEmpty ? tx.note : _typeLabel(tx.type),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${positive ? '+' : ''}${tx.amount}',
                  style: amountStyle,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel(tx),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          offset: Offset(0, 4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _relativeTxTime(tx.createdAt, now),
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.4),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        offset: Offset(0, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
