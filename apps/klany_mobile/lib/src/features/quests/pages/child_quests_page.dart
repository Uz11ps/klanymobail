import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../auth/child_session.dart';
import '../../home/child_avatar_picker_flow.dart';
import '../../home/child_dashboard_profile_card.dart';
import '../../home/child_soft_ui.dart';
import '../quests_repository.dart';
import '../../../core/app_snackbar.dart';

/// Фон карточек по [Figma «Биржа задач» node 0:305+](https://www.figma.com/design/z72tmzXGfrKzFPQMqrL1ZB/Untitled?node-id=0-285).
const _kMintCard = Color(0xFFD9F6C2);
const _kLavenderCard = Color(0xFFD8CBF7);
const _kSkyCard = Color(0xFFC1DCF5);

const _cardColors = <Color>[_kMintCard, _kLavenderCard, _kSkyCard];

List<BoxShadow> _questCardOuterShadows(Color bg) {
  if (bg == _kMintCard) {
    return [
      BoxShadow(
        color: const Color.fromRGBO(222, 247, 203, 0.35),
        blurRadius: 50,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: const Color.fromRGBO(173, 211, 165, 0.35),
        blurRadius: 20,
        offset: const Offset(0, 13),
      ),
    ];
  }
  if (bg == _kLavenderCard) {
    return [
      BoxShadow(
        color: const Color.fromRGBO(216, 203, 247, 0.35),
        blurRadius: 50,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: const Color.fromRGBO(179, 165, 211, 0.35),
        blurRadius: 20,
        offset: const Offset(0, 13),
      ),
    ];
  }
  return [
    BoxShadow(
      color: const Color.fromRGBO(193, 220, 255, 0.35),
      blurRadius: 50,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: const Color.fromRGBO(191, 219, 255, 0.35),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Дубликат теней с [ChildHomePage] — `_scaledMintStatShadows`.
List<BoxShadow> _questsScaledMintStatShadows(double scale) => [
  BoxShadow(
    color: const Color.fromRGBO(222, 247, 203, 0.26),
    blurRadius: 40 * scale,
    offset: Offset(0, 16 * scale),
  ),
  BoxShadow(
    color: const Color.fromRGBO(173, 211, 165, 0.22),
    blurRadius: 16 * scale,
    offset: Offset(0, 10 * scale),
  ),
];

/// Дубликат `_scaledLavenderStatShadows`.
List<BoxShadow> _questsScaledLavenderStatShadows(double scale) => [
  BoxShadow(
    color: const Color.fromRGBO(216, 203, 247, 0.26),
    blurRadius: 40 * scale,
    offset: Offset(0, 16 * scale),
  ),
  BoxShadow(
    color: const Color.fromRGBO(179, 165, 211, 0.22),
    blurRadius: 16 * scale,
    offset: Offset(0, 10 * scale),
  ),
];

Widget _questsDividerLine() {
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

class ChildQuestsPage extends ConsumerStatefulWidget {
  const ChildQuestsPage({super.key});

  @override
  ConsumerState<ChildQuestsPage> createState() => _ChildQuestsPageState();
}

class _ChildQuestsPageState extends ConsumerState<ChildQuestsPage> {
  Future<List<ChildQuestAssignmentItem>>? _future;
  String? _assignmentsChildId;
  int _tab = 0; // 0 = Мои задачи, 1 = Биржа

  Future<void> _reload() async {
    final session = ref.read(childSessionProvider).asData?.value;
    if (session == null) return;
    final f = ref
        .read(questsRepositoryProvider)
        .getChildAssignments(session.childId);
    setState(() {
      _assignmentsChildId = session.childId;
      _future = f;
    });
    await f;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.read(childSessionProvider).asData?.value;
    final id = session?.childId;
    if (id == null) return;
    if (_assignmentsChildId != id) {
      _assignmentsChildId = id;
      _future = ref.read(questsRepositoryProvider).getChildAssignments(id);
    } else {
      _future ??= ref.read(questsRepositoryProvider).getChildAssignments(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: Text('Сессия ребёнка не найдена'));
    }

    return FutureBuilder<List<ChildQuestAssignmentItem>>(
      future: _future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ChildQuestAssignmentItem>[];
        final personal = all
            .where((a) => a.distributionType != 'exchange')
            .toList();
        final exchange = all
            .where((a) => a.distributionType == 'exchange')
            .toList();
        final completed = all
            .where(
              (a) =>
                  a.status == 'completed' ||
                  a.status == 'done' ||
                  a.status == 'approved',
            )
            .length;
        final current = _tab == 0 ? personal : exchange;

        final screenW = MediaQuery.sizeOf(context).width;
        final cw = kFigmaChildDashboardContentWidth(screenW);
        final hPad = kFigmaChildDashboardHorizontalPadding(screenW, cw);
        final s = kFigmaChildDashboardLayoutScale(cw);
        final bottomPad =
            ChildBottomClanBar.scrollBottomClearance(context) + 28;

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
              child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(hPad, 26, hPad, bottomPad),
                    children: [
                      SizedBox(
                        width: cw,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                              child: Text(
                                _tab == 0 ? 'Мои задачи' : 'Биржа задач',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _reload,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: SvgPicture.asset(
                                        'assets/figma/nav_refresh.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.black,
                                          BlendMode.srcIn,
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
                      const SizedBox(height: 20),
                      ChildDashboardProfileCard(
                        layoutScale: s,
                        completedCount: completed,
                        onAvatarTap: () =>
                            runChildAvatarPickerFlow(context, ref),
                      ),
                      const SizedBox(height: 20),
                      _questsDividerLine(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ChildQuestsStatTile(
                              scale: s,
                              label: 'Мои задачи',
                              value: '${personal.length}',
                              background: kFigmaChildStatMint,
                              verticalPaddingPx: 34,
                              outerShadows: _questsScaledMintStatShadows(s),
                              onTap: () => setState(() => _tab = 0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ChildQuestsStatTile(
                              scale: s,
                              label: 'Биржа',
                              value: '${exchange.length}',
                              background: kFigmaChildStatLavender,
                              verticalPaddingPx: 30,
                              outerShadows: _questsScaledLavenderStatShadows(s),
                              onTap: () => setState(() => _tab = 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (snapshot.hasError)
                        ChildSoftCard(child: Text('Ошибка: ${snapshot.error}')),
                      if (!snapshot.hasError &&
                          snapshot.connectionState != ConnectionState.waiting &&
                          current.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              _tab == 0
                                  ? 'Личных задач пока нет'
                                  : 'На бирже пока нет доступных задач',
                              style: const TextStyle(color: kChildInkMuted),
                            ),
                          ),
                        ),
                      ...current.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ChildQuestCard(
                            item: e.value,
                            bg: _cardColors[e.key % _cardColors.length],
                            isExchange: _tab == 1,
                            onChanged: _reload,
                            onClaimedFromMarket: () {
                              if (mounted) setState(() => _tab = 0);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Визуально совпадает с `_StatTile` на [ChildHomePage]; добавлен [InkWell] для вкладок.
class _ChildQuestsStatTile extends StatelessWidget {
  const _ChildQuestsStatTile({
    required this.scale,
    required this.label,
    required this.value,
    required this.background,
    required this.outerShadows,
    required this.verticalPaddingPx,
    required this.onTap,
  });

  final double scale;
  final String label;
  final String value;
  final Color background;
  final List<BoxShadow> outerShadows;
  final double verticalPaddingPx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = 22.0 * scale;
    final borderRadius = BorderRadius.circular(r);
    return SizedBox(
      height: 142 * scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: outerShadows,
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: ColoredBox(
                color: background,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: verticalPaddingPx * scale,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 17 * scale,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 11 * scale),
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 34 * scale,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Календарный [ChildQuestAssignmentItem.dueAt] или дедлайн по лимиту времени с [ChildQuestAssignmentItem.createdAt].
DateTime? _effectiveDueAtForChildItem(ChildQuestAssignmentItem q) {
  if (q.dueAt != null) return q.dueAt;
  final m = q.timeLimitMinutes;
  if (m == null) return null;
  return q.createdAt.add(Duration(minutes: m));
}

String _ruDayWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'дня';
  return 'дней';
}

String _ruHourWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'часа';
  return 'часов';
}

String _ruMinuteWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'минута';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'минуты';
  return 'минут';
}

String _ruSecondWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'секунда';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'секунды';
  }
  return 'секунд';
}

/// Остаток времени или «Просрочено на …» — без заглушки «Срочно» (она появлялась при `< 24 ч` из‑за `.inDays == 0`).
String _childQuestDeadlineLine(DateTime? at) {
  if (at == null) return 'Без дедлайна';
  final diff = at.difference(DateTime.now());
  if (diff.isNegative) {
    return 'Просрочено на ${_formatPositiveDurationRu(-diff)}';
  }
  return 'Осталось ${_formatPositiveDurationRu(diff)}';
}

String _formatPositiveDurationRu(Duration d) {
  if (d < const Duration(minutes: 1)) {
    final s = d.inSeconds.clamp(0, 59);
    return s <= 0 ? 'меньше минуты' : '$s ${_ruSecondWord(s)}';
  }

  final days = d.inDays;
  var rest = d - Duration(days: days);
  final hours = rest.inHours;
  rest -= Duration(hours: hours);
  final minutes = rest.inMinutes;

  final parts = <String>[];
  if (days > 0) parts.add('$days ${_ruDayWord(days)}');
  if (hours > 0) parts.add('$hours ${_ruHourWord(hours)}');
  if (minutes > 0) parts.add('$minutes ${_ruMinuteWord(minutes)}');
  if (parts.isEmpty) return 'меньше минуты';
  return parts.join(' ');
}

class _ChildQuestCard extends ConsumerStatefulWidget {
  const _ChildQuestCard({
    required this.item,
    required this.bg,
    required this.isExchange,
    required this.onChanged,
    this.onClaimedFromMarket,
  });

  final ChildQuestAssignmentItem item;
  final Color bg;
  final bool isExchange;
  final VoidCallback onChanged;

  /// После успешного «Взять с биржи» — переключить родителя на вкладку «Мои задачи».
  final VoidCallback? onClaimedFromMarket;

  @override
  ConsumerState<_ChildQuestCard> createState() => _ChildQuestCardState();
}

class _ChildQuestCardState extends ConsumerState<_ChildQuestCard> {
  final _picker = ImagePicker();
  bool _busy = false;
  bool _takenLocally = false;
  bool _submittedLocally = false;

  String get _effectiveStatus {
    if (_submittedLocally) return 'on_review';
    if (_takenLocally && widget.item.status == 'market') return 'in_progress';
    return widget.item.status;
  }

  bool get _canTake => _effectiveStatus == 'market';
  bool get _canSubmit =>
      !_submittedLocally &&
      (_effectiveStatus == 'assigned' || _effectiveStatus == 'in_progress');

  Future<void> _takeQuest() async {
    if (_busy || !_canTake) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(questsRepositoryProvider)
          .takeFromMarket(widget.item.questId);
      if (!mounted) return;
      setState(() => _takenLocally = true);
      widget.onClaimedFromMarket?.call();
      context.showKlanySnackBar(
        const SnackBar(content: Text('Квест взят в работу')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitDone({required bool withPhoto}) async {
    if (_busy || !_canSubmit) return;
    setState(() => _busy = true);
    try {
      XFile? photo;
      if (withPhoto) {
        photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
        );
      }
      await ref
          .read(questsRepositoryProvider)
          .submitQuestWithEvidence(
            questId: widget.item.questId,
            evidenceFile: photo,
          );
      if (!mounted) return;
      setState(() => _submittedLocally = true);
      context.showKlanySnackBar(
        const SnackBar(content: Text('Отправлено на проверку')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      context.showKlanySnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFlow() async {
    if (widget.isExchange && _canTake) {
      await _takeQuest();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Выполнено без фото'),
              onTap: () => Navigator.of(ctx).pop('no_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo),
              title: const Text('Выполнено + фото'),
              onTap: () => Navigator.of(ctx).pop('with_photo'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _submitDone(withPhoto: choice == 'with_photo');
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.item.rewardAmount;
    final photoLabel = widget.item.autoApprove
        ? 'Без фото-отчёта'
        : 'Фото-отчёт';
    final deadlineLine = _childQuestDeadlineLine(
      _effectiveDueAtForChildItem(widget.item),
    );
    final btnLabel = () {
      if (_busy) return 'Подождите…';
      if (_effectiveStatus == 'overdue') return 'Просрочено';
      if (_submittedLocally || _effectiveStatus == 'submitted') {
        return 'На проверке';
      }
      if (_effectiveStatus == 'approved' ||
          _effectiveStatus == 'completed' ||
          _effectiveStatus == 'done') {
        return 'Выполнено';
      }
      if (_canTake && widget.isExchange) return 'Взять с биржи';
      if (_canSubmit) return 'Подтвердить выполнение';
      return widget.isExchange ? 'Взять с биржи' : 'Открыть';
    }();

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
      decoration: BoxDecoration(
        color: widget.bg,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: _questCardOuterShadows(widget.bg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.title,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kChildInk,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '+$reward монет',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kChildInk,
            ),
          ),
          Text(
            photoLabel,
            style: GoogleFonts.nunito(fontSize: 16, color: kChildInk),
          ),
          Text(
            deadlineLine,
            style: GoogleFonts.nunito(fontSize: 16, color: kChildInk),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: (_busy || (!_canTake && !_canSubmit)) ? null : _openFlow,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      btnLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kChildInk,
                      ),
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
