import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage_presign.dart';
import '../../auth/child_self_avatar.dart';
import '../../auth/child_session.dart';
import '../../auth/child_pin_store.dart';
import '../../auth/device_identity.dart';
import '../../notifications/fcm.dart';
import '../../notifications/notifications_repository.dart';
import '../../onboarding/onboarding_store.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../onboarding/onboarding_tour_dialog.dart';
import '../../quests/pages/child_quests_page.dart';
import '../../quests/quests_repository.dart';
import '../../shop/pages/child_shop_page.dart';
import '../../wallet/wallet_repository.dart';
import '../avatar_store.dart';
import '../child_soft_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Экран ребёнка — полностью пересобран. Каркас Scaffold совпадает с [ParentHomePage]:
// extendBody, LayoutBuilder → SizedBox(width,height) → IndexedStack.expand.
// ═══════════════════════════════════════════════════════════════════════════════

TextStyle _nunito({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double height = 1.0,
  double letterSpacing = 0,
}) =>
    GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kChildInk,
      height: height,
      letterSpacing: letterSpacing,
    );

const List<BoxShadow> _mintTileShadows = [
  BoxShadow(
    color: Color.fromRGBO(222, 247, 203, 0.35),
    blurRadius: 50,
    offset: Offset(0, 20),
  ),
  BoxShadow(
    color: Color.fromRGBO(173, 211, 165, 0.35),
    blurRadius: 20,
    offset: Offset(0, 13),
  ),
];

const List<BoxShadow> _lavenderTileShadows = [
  BoxShadow(
    color: Color.fromRGBO(216, 203, 247, 0.35),
    blurRadius: 50,
    offset: Offset(0, 20),
  ),
  BoxShadow(
    color: Color.fromRGBO(179, 165, 211, 0.35),
    blurRadius: 20,
    offset: Offset(0, 13),
  ),
];

class _SoftCardHighlight extends StatelessWidget {
  const _SoftCardHighlight({required this.radius});

  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.transparent,
                Colors.white.withValues(alpha: 0.52),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _dividerLine() {
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

class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  int _index = 0;
  Timer? _sessionTimer;
  int _registerAttempts = 0;

  @override
  void initState() {
    super.initState();
    _registerDevice();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    _sessionTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      await ref.read(childSessionProvider.notifier).validateStillActive();
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybeShowTour() async {
    final seen = await OnboardingStore.isChildTourSeen();
    if (seen || !mounted) return;
    await showOnboardingTourDialog(
      context: context,
      title: childTourTitle,
      steps: childTourSteps,
    );
    await OnboardingStore.setChildTourSeen();
  }

  Future<void> _registerDevice() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final identity = await DeviceIdentityStore.getOrCreate();
    final pushToken = await Fcm.getToken();
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.windows => 'windows',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.linux => 'linux',
            TargetPlatform.fuchsia => 'fuchsia',
          };
    if ((platform == 'android' || platform == 'ios') &&
        (pushToken == null || pushToken.isEmpty)) {
      if (_registerAttempts < 3) {
        _registerAttempts += 1;
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) _registerDevice();
        });
      }
      return;
    }
    await ref.read(notificationsRepositoryProvider).registerDevice(
          platform: platform,
          pseudoPushToken: (pushToken != null && pushToken.isNotEmpty)
              ? pushToken
              : 'child-${identity.deviceId}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const _ChildHomeDashboard(),
      const ChildQuestsPage(),
      const ChildShopPage(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: SizedBox.expand(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final h = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height;
                return SizedBox(
                  width: w,
                  height: h,
                  child: IndexedStack(
                    index: _index,
                    sizing: StackFit.expand,
                    children: tabs,
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: ChildBottomClanBar(
            currentIndex: _index,
            onSelected: (i) => setState(() => _index = i),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Дашборд (вкладка «Дом»)
// ─────────────────────────────────────────────────────────────────────────────

class _ChildHomeDashboard extends ConsumerStatefulWidget {
  const _ChildHomeDashboard();

  @override
  ConsumerState<_ChildHomeDashboard> createState() => _ChildHomeDashboardState();
}

class _ChildHomeDashboardState extends ConsumerState<_ChildHomeDashboard> {
  bool _initialLoading = true;
  bool _refreshing = false;
  Object? _loadError;
  _OverviewModel? _model;

  static double _targetContentWidth(double screenWidth) {
    if (screenWidth < 430) return math.max(0.0, screenWidth - 40);
    if (screenWidth < 700) return math.min(screenWidth - 56, 430);
    return math.min(screenWidth * 0.56, 560);
  }

  static double _layoutScale(double contentWidth) =>
      (contentWidth / 353).clamp(0.88, 1.22).toDouble();

  @override
  void initState() {
    super.initState();
    _load(showSpinner: true);
  }

  Future<_OverviewModel> _fetch(String childId) async {
    final wallet =
        await ref.read(walletRepositoryProvider).getChildWallet(childId);
    final list =
        await ref.read(questsRepositoryProvider).getChildAssignments(childId);
    final active = list
        .where(
          (a) =>
              a.distributionType != 'exchange' &&
              a.status != 'done' &&
              a.status != 'completed',
        )
        .length;
    final exchange = list.where((a) => a.distributionType == 'exchange').length;
    final done = list
        .where((a) => a.status == 'completed' || a.status == 'done')
        .length;
    final balance = wallet?.balance ?? 0;
    final rawGoal = wallet?.goalAmount ?? 10000;
    final goal = rawGoal > 0 ? rawGoal : 10000;
    return _OverviewModel(
      walletBalance: balance,
      activeAssignments: active,
      exchangeCount: exchange,
      completedCount: done,
      goalCurrent: balance,
      goalTarget: goal,
      goalProgress: balance / goal,
    );
  }

  Future<void> _load({bool showSpinner = false}) async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _initialLoading = false;
        _refreshing = false;
      });
      return;
    }

    setState(() {
      _loadError = null;
      if (showSpinner && _model == null) {
        _initialLoading = true;
      } else if (_model != null) {
        _refreshing = true;
      }
    });

    try {
      final m = await _fetch(session.childId);
      if (!mounted) return;
      setState(() => _model = m);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _openAccountSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: kChildSurfaceWhite,
      builder: (_) => _ChildAccountSheet(
        onSignOut: () => ref.read(childSessionProvider.notifier).clear(),
      ),
    );
  }

  String _taskWordRu(int n) {
    final t = n % 10;
    final h = n % 100;
    if (t == 1 && h != 11) return 'задача';
    if (t >= 2 && t <= 4 && (h < 12 || h > 14)) return 'задачи';
    return 'задач';
  }

  String _formatBalance(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _reverseTaskFlow() async {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Обратная задача',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Поставь спец-цель с родителем. Когда соберёшь нужную сумму — родитель её исполнит.',
              style: TextStyle(fontSize: 13, color: kChildInkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название цели',
                hintText: 'Например: Подарок маме',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сколько монет нужно',
                hintText: '500',
              ),
            ),
            const SizedBox(height: 16),
            FigmaDialogActionStack(
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final title = titleCtl.text.trim();
    final amount = int.tryParse(amountCtl.text.trim()) ?? 0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название и сумму')),
      );
      return;
    }
    final msgr = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(questsRepositoryProvider)
          .createReverseQuest(title: title, rewardAmount: amount);
      if (!mounted) return;
      msgr.showSnackBar(
        SnackBar(
          content: Text('Цель «$title» на $amount монет отправлена родителю'),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      msgr.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _avatarFlow(BuildContext origin) async {
    final msgr = ScaffoldMessenger.of(origin);
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;

    final pick = await showModalBottomSheet<String>(
      context: origin,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Готовый аватар'),
              onTap: () => Navigator.pop(ctx, 'preset'),
            ),
          ],
        ),
      ),
    );
    if (pick == null || !origin.mounted) return;

    try {
      if (pick == 'gallery') {
        final img = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (img == null || !origin.mounted) return;
        await uploadChildAvatarXFile(ref, img);
        return;
      }

      var selected = 1;
      final presetOk = await showDialog<bool>(
        context: origin,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Аватар'),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: AvatarStore.totalAvatars,
                    itemBuilder: (_, i) {
                      final idx = i + 1;
                      final sel = idx == selected;
                      return GestureDetector(
                        onTap: () => setSt(() => selected = idx),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel
                                  ? kFigmaChildScreenBlue
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              AvatarStore.assetForIndex(idx),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: kFigmaLandingCtaHeight,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            kFigmaLandingCtaHeight / 2,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Сохранить'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FigmaDialogCancelButton(
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (presetOk != true || !origin.mounted) return;
      final bytes =
          await rootBundle.load(AvatarStore.assetForIndex(selected));
      await uploadChildAvatarPngBytes(ref, bytes.buffer.asUint8List());
      await AvatarStore.setIndex('child:${session.childId}', selected);
    } catch (e) {
      if (origin.mounted) {
        msgr.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: Text('Сессия ребёнка не найдена'));
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final cw = _targetContentWidth(screenW);
    final s = _layoutScale(cw);
    final hPad = ((screenW - cw) / 2).clamp(16.0, 400.0).toDouble();
    final bottomPad = 24 + MediaQuery.viewPaddingOf(context).bottom + 8;
    final gap = 20.0 * s;
    final name = session.childDisplayName.trim().isEmpty
        ? 'Привет!'
        : session.childDisplayName;

    late final List<Widget> body;

    if (_initialLoading && _model == null) {
      body = [
        _DashboardHeader(
          scale: s,
          onReload: () => _load(),
          onMenu: _openAccountSheet,
        ),
        SizedBox(height: 25 * s),
        SizedBox(
          height: math.max(320, MediaQuery.sizeOf(context).height * 0.35),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3 * s,
              color: kFigmaChildScreenBlue,
            ),
          ),
        ),
      ];
    } else if (_model == null) {
      body = [
        _DashboardHeader(
          scale: s,
          onReload: () => _load(),
          onMenu: _openAccountSheet,
        ),
        SizedBox(height: 20 * s),
        Text(
          'Не удалось загрузить данные',
          textAlign: TextAlign.center,
          style: _nunito(
            fontSize: 16 * s,
            fontWeight: FontWeight.w700,
            color: kChildInkMuted,
          ),
        ),
        SizedBox(height: 12 * s),
        if (_loadError != null) ...[
          Text(
            _loadError.toString(),
            textAlign: TextAlign.center,
            style: _nunito(
              fontSize: 12 * s,
              fontWeight: FontWeight.w400,
              color: kChildInkMuted,
            ),
          ),
          SizedBox(height: 12 * s),
        ],
        TextButton(
          onPressed: () => _load(showSpinner: true),
          child: Text(
            'Повторить',
            style: _nunito(
              fontSize: 15 * s,
              fontWeight: FontWeight.w700,
              color: kFigmaChildScreenBlue,
            ),
          ),
        ),
      ];
    } else {
      final m = _model!;
      final done = m.completedCount;
      body = [
        _DashboardHeader(
          scale: s,
          onReload: () => _load(),
          onMenu: _openAccountSheet,
        ),
        if (_refreshing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            color: kFigmaChildScreenBlue,
            backgroundColor: kChildOutline,
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(height: gap),
        SizedBox(
          width: double.infinity,
          child: _DashboardProfileCard(
            scale: s,
            session: session,
            displayName: name,
            completedLine: '$done ${_taskWordRu(done)} выполнено',
            balance: m.walletBalance,
            formatInt: _formatBalance,
            onAvatar: () => _avatarFlow(context),
          ),
        ),
        SizedBox(height: gap),
        _dividerLine(),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                scale: s,
                label: 'Мои задачи',
                value: '${m.activeAssignments}',
                background: kFigmaChildStatMint,
                outerShadows: _mintTileShadows,
              ),
            ),
            SizedBox(width: 7 * s),
            Expanded(
              child: _StatTile(
                scale: s,
                label: 'Биржа',
                value: '${m.exchangeCount}',
                background: kFigmaChildStatLavender,
                outerShadows: _lavenderTileShadows,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        _dividerLine(),
        SizedBox(height: gap),
        _DashboardGoalCard(
          scale: s,
          progress: m.goalProgress.clamp(0.0, 1.0),
          caption:
              '${_formatBalance(m.goalCurrent)} / ${_formatBalance(m.goalTarget)} монет',
        ),
        SizedBox(height: gap),
        _dividerLine(),
        SizedBox(height: gap),
        _DashboardReverseTaskCard(
          scale: s,
          onCreate: _reverseTaskFlow,
        ),
      ];
    }

    return Stack(
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
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, bottomPad),
              children: body,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewModel {
  const _OverviewModel({
    required this.walletBalance,
    required this.activeAssignments,
    this.exchangeCount = 0,
    this.completedCount = 0,
    this.goalCurrent = 0,
    this.goalTarget = 10000,
    this.goalProgress = 0.0,
  });

  final int walletBalance;
  final int activeAssignments;
  final int exchangeCount;
  final int completedCount;
  final int goalCurrent;
  final int goalTarget;
  final double goalProgress;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.scale,
    required this.onReload,
    required this.onMenu,
  });

  final double scale;
  final VoidCallback onReload;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'CLAN CAPITAL',
            textAlign: TextAlign.center,
            style: _nunito(
              fontSize: 32 * scale,
              fontWeight: FontWeight.w800,
              color: kFigmaChildScreenBlue,
              height: 1.05,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              children: [
                _RoundWhiteButton(
                  onTap: onReload,
                  child: SvgPicture.asset(
                    'assets/figma/nav_refresh.svg',
                    width: 24 * scale,
                    height: 24 * scale,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
                _RoundWhiteButton(
                  onTap: onMenu,
                  child: SvgPicture.asset(
                    'assets/figma/child_nav_menu_dots.svg',
                    width: 24 * scale,
                    height: 24 * scale,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundWhiteButton extends StatelessWidget {
  const _RoundWhiteButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const r = 41.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: child),
        ),
      ),
    );
  }
}

class _DashboardProfileCard extends StatelessWidget {
  const _DashboardProfileCard({
    required this.scale,
    required this.session,
    required this.displayName,
    required this.completedLine,
    required this.balance,
    required this.formatInt,
    required this.onAvatar,
  });

  final double scale;
  final ChildSession session;
  final String displayName;
  final String completedLine;
  final int balance;
  final String Function(int) formatInt;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20 * scale);
    final size = 107 * scale;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20 * scale,
            offset: Offset(0, 10 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Padding(
              padding: EdgeInsets.all(20 * scale),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Builder(
                          builder: (context) {
                            final key = session.avatarObjectKey;
                            if (key == null || key.isEmpty) {
                              return UserAvatar(
                                userKey: 'child:${session.childId}',
                                size: size,
                                fallbackText: displayName.isEmpty
                                    ? '?'
                                    : displayName.characters.first
                                        .toUpperCase(),
                              );
                            }
                            return FutureBuilder<String?>(
                              key: ValueKey(key),
                              future: presignStorageDownload(
                                accessToken: session.accessToken,
                                bucket: 'member-avatars',
                                objectKey: key,
                              ),
                              builder: (context, snap) => UserAvatar(
                                userKey: 'child:${session.childId}',
                                size: size,
                                fallbackText: displayName.isEmpty
                                    ? '?'
                                    : displayName.characters.first
                                        .toUpperCase(),
                                remoteImageUrl: snap.data,
                              ),
                            );
                          },
                        ),
                        Positioned(
                          right: 2 * scale,
                          bottom: 2 * scale,
                          child: Container(
                            width: 28 * scale,
                            height: 28 * scale,
                            decoration: BoxDecoration(
                              color: kFigmaChildScreenBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2 * scale,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.edit,
                              size: 14 * scale,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _nunito(
                            fontSize: 24 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        Text(
                          completedLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _nunito(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w400,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        Container(
                          height: 29 * scale,
                          padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                          decoration: BoxDecoration(
                            color: kFigmaChildBalancePill,
                            borderRadius: BorderRadius.circular(25 * scale),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CoinStackIcon(
                                size: 18 * scale,
                                color: kFigmaChildScreenBlue,
                              ),
                              SizedBox(width: 3 * scale),
                              Text(
                                formatInt(balance),
                                style: _nunito(
                                  fontSize: 24 * scale,
                                  fontWeight: FontWeight.w800,
                                  color: kFigmaChildScreenBlue,
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
            Positioned.fill(child: _SoftCardHighlight(radius: r)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.scale,
    required this.label,
    required this.value,
    required this.background,
    required this.outerShadows,
  });

  final double scale;
  final String label;
  final String value;
  final Color background;
  final List<BoxShadow> outerShadows;

  @override
  Widget build(BuildContext context) {
    final r = 25.0 * scale;
    final borderRadius = BorderRadius.circular(r);
    return AspectRatio(
      aspectRatio: 173 / 165,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: outerShadows,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: background),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _nunito(
                        fontSize: 20 * scale,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 15 * scale),
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: _nunito(
                        fontSize: 40 * scale,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: _SoftCardHighlight(radius: borderRadius),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardGoalCard extends StatelessWidget {
  const _DashboardGoalCard({
    required this.scale,
    required this.progress,
    required this.caption,
  });

  final double scale;
  final double progress;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(25 * scale);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(249, 232, 165, 0.35),
            blurRadius: 25 * scale,
            offset: Offset(0, 20 * scale),
          ),
          BoxShadow(
            color: const Color.fromRGBO(249, 232, 165, 0.35),
            blurRadius: 10 * scale,
            offset: Offset(0, 10 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFFF9E8A5))),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10 * scale,
                vertical: 38 * scale,
              ),
              child: Column(
                children: [
                  Text(
                    'Текущая цель',
                    textAlign: TextAlign.center,
                    style: _nunito(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 15 * scale),
                  FractionallySizedBox(
                    widthFactor: 294 / 333,
                    child: _GoalProgressTrack(progress: progress),
                  ),
                  SizedBox(height: 15 * scale),
                  Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: _nunito(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF515151),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: _SoftCardHighlight(radius: r)),
          ],
        ),
      ),
    );
  }
}

class _GoalProgressTrack extends StatelessWidget {
  const _GoalProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const trackH = 27.0;
        const thumbW = 30.0;
        const thumbH = 28.0;
        final clamped = progress.clamp(0.0, 1.0);
        final thumbX = ((w - thumbW) * clamped)
            .clamp(0.0, math.max(0.0, w - thumbW))
            .toDouble();

        return SizedBox(
          height: trackH,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: w,
                height: trackH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.31),
                  ),
                ),
              ),
              Positioned(
                left: thumbX,
                top: (trackH - thumbH) / 2,
                child: Container(
                  width: thumbW,
                  height: thumbH,
                  decoration: BoxDecoration(
                    color: kFigmaChildGoalThumb,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      width: 0.5,
                      color: Colors.black.withValues(alpha: 0.31),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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

class _DashboardReverseTaskCard extends StatelessWidget {
  const _DashboardReverseTaskCard({
    required this.scale,
    required this.onCreate,
  });

  final double scale;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(25 * scale);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10 * scale,
            offset: Offset(0, 10 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                10 * scale,
                20 * scale,
                10 * scale,
                20 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Обратная задача',
                    style: _nunito(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  Text(
                    'Поставь одну спец-цель с родителем. Собранное идет в цель.',
                    style: _nunito(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28 * scale),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SoftButton(
                          onTap: onCreate,
                          label: 'Создать',
                          bg: kFigmaChildStatMint,
                          fg: Colors.black,
                          height: 56 * scale,
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w700,
                          boxShadow: kFigmaMintCtaGlow,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                          labelStyle: _nunito(
                            fontSize: 20 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Positioned.fill(
                          child: _SoftCardHighlight(
                            radius: BorderRadius.circular(28 * scale),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: _SoftCardHighlight(radius: r)),
          ],
        ),
      ),
    );
  }
}

class _ChildAccountSheet extends ConsumerStatefulWidget {
  const _ChildAccountSheet({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<_ChildAccountSheet> createState() =>
      _ChildAccountSheetState();
}

class _ChildAccountSheetState extends ConsumerState<_ChildAccountSheet> {
  Future<String?>? _authCodeFuture;
  String? _authCodeToken;

  Future<String?> _authCode(String accessToken) {
    return ref
        .read(passwordlessChildRepositoryProvider)
        .getMyAuthCode(accessToken: accessToken);
  }

  Future<void> _tourAgain() async {
    await showOnboardingTourDialog(
      context: context,
      title: childTourTitle,
      steps: childTourSteps,
    );
    await OnboardingStore.setChildTourSeen();
  }

  Future<void> _changePin() async {
    final pinCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN-код ребёнка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: pinCtl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Новый PIN (6 цифр)',
                counterText: '',
              ),
            ),
            TextField(
              controller: confirmCtl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Повторите PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FigmaDialogActionStack(
              onCancel: () => Navigator.of(ctx).pop(false),
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final pin = pinCtl.text.trim();
    final confirm = confirmCtl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN должен состоять из 6 цифр')),
      );
      return;
    }
    if (pin != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN-коды не совпадают')),
      );
      return;
    }

    await ChildPinStore.setPin(pin);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN сохранён')),
    );
  }

  Future<void> _dropPin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Удалить PIN-код для быстрого входа ребёнка?'),
            const SizedBox(height: 16),
            FigmaDialogActionStack(
              onCancel: () => Navigator.of(ctx).pop(false),
              onConfirm: () => Navigator.of(ctx).pop(true),
              confirmLabel: 'Удалить',
              confirmGradient:
                  FigmaDialogActionStack.destructiveGradientVertical,
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await ChildPinStore.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN удалён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final token = session?.accessToken ?? '';
    if (token.isNotEmpty && _authCodeToken != token) {
      _authCodeToken = token;
      _authCodeFuture = _authCode(token);
    }

    return FutureBuilder<bool>(
      future: ChildPinStore.hasPin(),
      builder: (context, snap) {
        final hasPin = snap.data ?? false;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Аккаунт'),
                subtitle: Text('Ребёнок / доступ по подтверждению'),
              ),
              FutureBuilder<String?>(
                future: _authCodeFuture,
                builder: (context, codeSnap) {
                  final code = codeSnap.data ?? '------';
                  return ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('Код входа ребёнка'),
                    subtitle: Text(
                      '$code\nИспользуйте этот код для входа с другого телефона.',
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pin),
                title: Text(hasPin ? 'Сменить PIN-код' : 'Установить PIN-код'),
                subtitle: const Text('6 цифр для быстрого входа ребёнка'),
                onTap: _changePin,
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Сбросить PIN-код'),
                  onTap: _dropPin,
                ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Показать обучение снова'),
                onTap: _tourAgain,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Выйти'),
                onTap: widget.onSignOut,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
