import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_snackbar.dart';
import '../auth/child_self_avatar.dart';
import '../auth/child_session.dart';
import 'avatar_store.dart';
import 'child_soft_ui.dart';

/// Выбор аватара ребёнка: галерея или пресеты — один поток для «Дом», «Биржа», «Магазин».
Future<void> runChildAvatarPickerFlow(BuildContext origin, WidgetRef ref) async {
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    final bytes = await rootBundle.load(AvatarStore.assetForIndex(selected));
    await uploadChildAvatarPngBytes(ref, bytes.buffer.asUint8List());
    await AvatarStore.setIndex('child:${session.childId}', selected);
  } catch (e) {
    if (origin.mounted) {
      origin.showKlanySnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}
