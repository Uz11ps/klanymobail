import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/app_snackbar.dart';
import '../../home/child_soft_ui.dart';
import '../../home/parent_screen_header.dart';
import '../subscription_repository.dart';

class SubscriptionPlansPage extends ConsumerStatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  ConsumerState<SubscriptionPlansPage> createState() =>
      _SubscriptionPlansPageState();
}

class _PlanPeriod {
  const _PlanPeriod(this.label, this.amountRub);

  final String label;
  final int amountRub;
}

class _SubscriptionPlansPageState extends ConsumerState<SubscriptionPlansPage> {
  static const _periods = <_PlanPeriod>[
    _PlanPeriod('1 мес.', 299),
    _PlanPeriod('3 мес.', 799),
    _PlanPeriod('6 мес.', 1399),
    _PlanPeriod('12 мес.', 2499),
  ];

  int _selectedPeriod = 3;
  bool _busy = false;
  Future<bool>? _premiumFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _premiumFuture ??= _isPremium();
  }

  Future<bool> _isPremium() async {
    final subs = await ref
        .read(subscriptionRepositoryProvider)
        .getFamilySubscriptions('');
    return subs.any(
      (s) =>
          s.planCode.toLowerCase().contains('premium') &&
          s.status.toLowerCase() != 'expired',
    );
  }

  Future<void> _buyPremium() async {
    if (_busy) return;
    final period = _periods[_selectedPeriod];
    setState(() => _busy = true);
    try {
      final orderId = await ref
          .read(subscriptionRepositoryProvider)
          .createPaymentOrder(
            planCode: 'premium',
            amountRub: period.amountRub.toDouble(),
          );
      final checkoutUrl = await ref
          .read(subscriptionRepositoryProvider)
          .createYookassaCheckoutUrl(orderId);
      if (!mounted) return;
      if ((checkoutUrl ?? '').isNotEmpty) {
        await launchUrlString(
          checkoutUrl!,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(
        SnackBar(content: Text('Ошибка создания платежа: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _premiumFuture,
      builder: (context, snapshot) {
        final isPremium = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pageWidth =
                        klanyResponsiveContentWidth(constraints.maxWidth);
                    final sidePadding =
                        constraints.maxWidth < 430 ? 19.0 : 24.0;
                    return Center(
                      child: SizedBox(
                        width: pageWidth,
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 34),
                          children: [
                            const ParentScreenHeader(
                              title: 'Тарифные планы',
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: sidePadding,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 20),
                                  const _StartPlanCard(),
                                  const SizedBox(height: 20),
                                  _PremiumPlanCard(
                                    periods: _periods,
                                    selectedIndex: _selectedPeriod,
                                    isPremium: isPremium,
                                    busy: _busy,
                                    onSelect: (i) =>
                                        setState(() => _selectedPeriod = i),
                                    onBuy: _buyPremium,
                                  ),
                                  const SizedBox(height: 30),
                                  Text(
                                    'На тарифе СТАРТ “Биржа задач” и “Витрина товаров” заблокированы.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Colors.black.withValues(alpha: 0.50),
                                      height: 1.25,
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
            ),
          ),
        );
      },
    );
  }
}

class _StartPlanCard extends StatelessWidget {
  const _StartPlanCard();

  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      color: const Color(0xFFF9E8A5),
      shadowColor: const Color(0xFFF9E8A5),
      title: 'СТАРТ (0 ₽)',
      subtitle: 'Для маленьких семей, пробующих механику',
      children: const [
        _FeatureLine(text: 'Участники: До 2 Детей'),
        _FeatureLine(text: 'Глава Клана: 1 родитель'),
        _FeatureLine(text: 'Цель: 1 общая цель'),
        _FeatureLine(text: 'Пополнение цели: ручное начисление Главой Клана'),
        _FeatureLine(text: 'Биржа задач', enabled: false),
        _FeatureLine(text: 'Магазин наград', enabled: false),
        SizedBox(height: 2),
        _DisabledPlanButton(),
      ],
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.periods,
    required this.selectedIndex,
    required this.isPremium,
    required this.busy,
    required this.onSelect,
    required this.onBuy,
  });

  final List<_PlanPeriod> periods;
  final int selectedIndex;
  final bool isPremium;
  final bool busy;
  final ValueChanged<int> onSelect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      color: const Color(0xFFC1D8F5),
      shadowColor: const Color(0xFFBFDBFF),
      title: 'PREMIUM',
      subtitle: 'Семейный капитал',
      children: [
        const _FeatureLine(text: 'Безлимит участников', premium: true),
        const _FeatureLine(text: 'Глава Клана: до 2 админов', premium: true),
        const _FeatureLine(
          text: 'Биржа задач: Прямые, Обратные, VIP',
          premium: true,
        ),
        const _FeatureLine(
          text: 'Магазин наград: покупка наград',
          premium: true,
        ),
        const _FeatureLine(text: 'Сгорание и дедлайны', premium: true),
        const _FeatureLine(text: 'Статистика доходов/расходов', premium: true),
        const SizedBox(height: 2),
        Row(
          children: List.generate(periods.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == periods.length - 1 ? 0 : 10,
                ),
                child: _PriceChip(
                  period: periods[i],
                  selected: i == selectedIndex,
                  best: i == 3,
                  onTap: () => onSelect(i),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        _PremiumActionButton(
          isPremium: isPremium,
          busy: busy,
          onPressed: onBuy,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.color,
    required this.shadowColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final Color color;
  final Color shadowColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 23, 17, 23),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(46),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 10,
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
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.60),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.text,
    this.enabled = true,
    this.premium = false,
  });

  final String text;
  final bool enabled;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: enabled ? 30 : 31,
            height: enabled ? 30 : 31,
            decoration: BoxDecoration(
              color: enabled
                  ? (premium
                        ? const Color(0xFF7EA6D9)
                        : const Color(0xFF7F9D72))
                  : const Color(0xFF84282D),
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: enabled ? 21 : 20,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisabledPlanButton extends StatelessWidget {
  const _DisabledPlanButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFC3BFBD),
        borderRadius: BorderRadius.circular(39),
      ),
      child: const Text(
        'Базовый план недоступен',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.period,
    required this.selected,
    required this.best,
    required this.onTap,
  });

  final _PlanPeriod period;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFD9F6C2) : const Color(0xFF9EC4F6);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(13),
          elevation: selected ? 2 : 0,
          shadowColor: const Color(0xFFD9F6C2).withValues(alpha: 0.35),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 59,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Text(
                '${period.label}\n(${period.amountRub}₽)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1.12,
                ),
              ),
            ),
          ),
        ),
        if (best)
          Positioned(
            top: -12,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(33),
              ),
              child: const Text(
                'ВЫГОДНО!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6D8B57),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.isPremium,
    required this.busy,
    required this.onPressed,
  });

  final bool isPremium;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: FilledButton(
        onPressed: isPremium || busy ? null : onPressed,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: const Color(0xFF9EC4F6),
          disabledForegroundColor: Colors.black,
          backgroundColor: const Color(0xFF9EC4F6),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(39),
          ),
          textStyle: kFigmaLandingCtaTextStyle,
        ),
        child: Text(
          isPremium
              ? 'PREMIUM УЖЕ АКТИВЕН'
              : busy
              ? 'ОФОРМЛЯЕМ...'
              : 'ОФОРМИТЬ PREMIUM',
        ),
      ),
    );
  }
}
