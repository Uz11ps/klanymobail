import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/child_session.dart';
import '../wallet/pages/child_wallet_page.dart';
import '../wallet/wallet_repository.dart';
import 'avatar_store.dart';
import 'child_soft_ui.dart';
import 'presigned_member_avatar.dart';

String _firstDisplayChar(String s) {
  if (s.isEmpty) return '?';
  final it = s.trim().runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current);
}

TextStyle _profileNunito({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double height = 1.0,
}) =>
    GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kChildInk,
      height: height,
    );

/// Аватар в карточке профиля (presign для загруженного фото ребёнка).
class ChildDashboardAvatar extends StatelessWidget {
  const ChildDashboardAvatar({
    super.key,
    required this.session,
    required this.displayName,
    required this.size,
  });

  final ChildSession session;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isEmpty
        ? '?'
        : _firstDisplayChar(displayName).toUpperCase();
    final key = session.avatarObjectKey;
    if (key == null || key.isEmpty) {
      return ClipOval(
        child: UserAvatar(
          userKey: 'child:${session.childId}',
          size: size,
          fallbackText: initial,
        ),
      );
    }
    return ClipOval(
      child: PresignedMemberAvatar(
        accessToken: session.accessToken,
        objectKey: key,
        userKey: 'child:${session.childId}',
        size: size,
        fallbackText: initial,
      ),
    );
  }
}

/// Белая карточка профиля — те же размеры, что [_DashboardProfileCard] на главной ребёнка.
class ChildDashboardProfileCard extends ConsumerStatefulWidget {
  const ChildDashboardProfileCard({
    super.key,
    required this.completedCount,
    required this.layoutScale,
    this.onAvatarTap,
    this.openWalletOnTap = true,
  });

  final int completedCount;
  final double layoutScale;
  final VoidCallback? onAvatarTap;

  /// На главном экране карточка не открывает кошелёк целиком (аватар отдельно).
  final bool openWalletOnTap;

  @override
  ConsumerState<ChildDashboardProfileCard> createState() =>
      _ChildDashboardProfileCardState();
}

class _ChildDashboardProfileCardState
    extends ConsumerState<ChildDashboardProfileCard> {
  String? _walletMemoChildId;
  Future<WalletSummary?>? _walletFuture;

  Future<WalletSummary?> _walletFutureForSession(ChildSession? session) {
    final id = session?.childId;
    if (id == null || id.isEmpty) {
      _walletMemoChildId = null;
      _walletFuture = Future.value(null);
      return _walletFuture!;
    }
    if (_walletMemoChildId != id) {
      _walletMemoChildId = id;
      _walletFuture =
          ref.read(walletRepositoryProvider).getChildWallet(id);
    }
    return _walletFuture!;
  }

  Widget _buildAvatarLead({
    required ChildSession? session,
    required String name,
    required String initial,
    required double avatarSize,
    required double layoutScale,
  }) {
    if (session == null) {
      return ClipOval(
        child: UserAvatar(
          userKey: 'child:guest',
          size: avatarSize,
          fallbackText: initial,
        ),
      );
    }

    final fallback = name.isEmpty
        ? '?'
        : _firstDisplayChar(name).toUpperCase();

    if (widget.onAvatarTap != null) {
      return GestureDetector(
        onTap: widget.onAvatarTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Builder(
              builder: (context) {
                final key = session.avatarObjectKey;
                if (key == null || key.isEmpty) {
                  return UserAvatar(
                    userKey: 'child:${session.childId}',
                    size: avatarSize,
                    fallbackText: fallback,
                  );
                }
                return PresignedMemberAvatar(
                  accessToken: session.accessToken,
                  objectKey: key,
                  userKey: 'child:${session.childId}',
                  size: avatarSize,
                  fallbackText: fallback,
                );
              },
            ),
            Positioned(
              right: 2 * layoutScale,
              bottom: 2 * layoutScale,
              child: Container(
                width: 24 * layoutScale,
                height: 24 * layoutScale,
                decoration: BoxDecoration(
                  color: kFigmaChildScreenBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5 * layoutScale,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.edit,
                  size: 12 * layoutScale,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ChildDashboardAvatar(
      session: session,
      displayName: name,
      size: avatarSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName.trim()
        : 'Участник';
    final initial =
        name.isNotEmpty ? _firstDisplayChar(name).toUpperCase() : '?';

    final layoutScale = widget.layoutScale;
    final r = BorderRadius.circular(18 * layoutScale);
    final avatarSize = 92 * layoutScale;

    return FutureBuilder<WalletSummary?>(
      future: _walletFutureForSession(session),
      builder: (context, walletSnap) {
        final balance = walletSnap.data?.balance ?? 0;

        final inner = Padding(
          padding: EdgeInsets.all(14 * layoutScale),
          child: Row(
            children: [
              _buildAvatarLead(
                session: session,
                name: name,
                initial: initial,
                avatarSize: avatarSize,
                layoutScale: layoutScale,
              ),
              SizedBox(width: 8 * layoutScale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _profileNunito(
                        fontSize: 21 * layoutScale,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 6 * layoutScale),
                    Text(
                      '${widget.completedCount} ${_taskWord(widget.completedCount)} выполнено',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _profileNunito(
                        fontSize: 14 * layoutScale,
                        fontWeight: FontWeight.w400,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    SizedBox(height: 6 * layoutScale),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 118 * layoutScale,
                        minHeight: 26 * layoutScale,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * layoutScale,
                          vertical: 4 * layoutScale,
                        ),
                        decoration: BoxDecoration(
                          color: kFigmaChildBalancePill,
                          borderRadius:
                              BorderRadius.circular(22 * layoutScale),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigmaProfileCoinStack(
                              width: 18 * layoutScale,
                              height: 17 * layoutScale,
                            ),
                            SizedBox(width: 6 * layoutScale),
                            Text(
                              _formatBalance(balance),
                              style: _profileNunito(
                                fontSize: 20 * layoutScale,
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
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18 * layoutScale,
                offset: Offset(0, 8 * layoutScale),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: r,
            child: widget.openWalletOnTap
                ? ColoredBox(
                    color: Colors.white,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChildWalletPage(),
                          ),
                        ),
                        child: inner,
                      ),
                    ),
                  )
                : ColoredBox(
                    color: Colors.white,
                    child: inner,
                  ),
          ),
        );
      },
    );
  }

  static String _formatBalance(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
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
