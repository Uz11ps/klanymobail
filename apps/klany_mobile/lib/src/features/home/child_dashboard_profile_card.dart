import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/storage_presign.dart';
import '../auth/child_session.dart';
import '../wallet/pages/child_wallet_page.dart';
import '../wallet/wallet_repository.dart';
import 'avatar_store.dart';
import 'child_soft_ui.dart';

/// Масштаб аватара 107 px относительно дашборда 92 px (Figma).
const double kChildDashboardProfileScale = 107 / 92;

String _firstDisplayChar(String s) {
  if (s.isEmpty) return '?';
  final it = s.trim().runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current);
}

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
    return FutureBuilder<String?>(
      key: ValueKey<String>(key),
      future: presignStorageDownload(
        accessToken: session.accessToken,
        bucket: 'member-avatars',
        objectKey: key,
      ),
      builder: (context, snap) => ClipOval(
        child: UserAvatar(
          userKey: 'child:${session.childId}',
          size: size,
          fallbackText: initial,
          remoteImageUrl: snap.data,
        ),
      ),
    );
  }
}

/// Белая карточка профиля: как на вкладках «Дом», «Задачи», «Магазин» ребёнка.
class ChildDashboardProfileCard extends ConsumerWidget {
  const ChildDashboardProfileCard({super.key, required this.completedCount});

  final int completedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(childSessionProvider).asData?.value;
    final name = session?.childDisplayName.trim().isNotEmpty == true
        ? session!.childDisplayName.trim()
        : 'Участник';
    final initial =
        name.isNotEmpty ? _firstDisplayChar(name).toUpperCase() : '?';
    final s = kChildDashboardProfileScale;
    final cardR = BorderRadius.circular(20);
    final avatarSize = 92 * s;

    return FutureBuilder<WalletSummary?>(
      future: session == null
          ? Future.value(null)
          : ref.read(walletRepositoryProvider).getChildWallet(session.childId),
      builder: (context, walletSnap) {
        final balance = walletSnap.data?.balance ?? 0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: cardR,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18 * s,
                offset: Offset(0, 8 * s),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardR,
            child: ColoredBox(
              color: Colors.white,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChildWalletPage(),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(14 * s),
                    child: Row(
                      children: [
                        if (session != null)
                          ChildDashboardAvatar(
                            session: session,
                            displayName: name,
                            size: avatarSize,
                          )
                        else
                          ClipOval(
                            child: UserAvatar(
                              userKey: 'child:guest',
                              size: avatarSize,
                              fallbackText: initial,
                            ),
                          ),
                        SizedBox(width: 8 * s),
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
                                  fontSize: 21 * s,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 6 * s),
                              Text(
                                '$completedCount ${_taskWord(completedCount)} выполнено',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 14 * s,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                              SizedBox(height: 6 * s),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: 118 * s,
                                  minHeight: 26 * s,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: kFigmaChildBalancePill,
                                    borderRadius: BorderRadius.circular(22 * s),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10 * s,
                                      vertical: 4 * s,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FigmaProfileCoinStack(
                                          width: 18 * s,
                                          height: 17 * s,
                                        ),
                                        SizedBox(width: 6 * s),
                                        Text(
                                          _formatBalance(balance),
                                          style: GoogleFonts.nunito(
                                            fontSize: 20 * s,
                                            fontWeight: FontWeight.w800,
                                            color: kFigmaChildScreenBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
