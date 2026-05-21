import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/profile_display_name.dart';
import '../../../core/storage_presign.dart';
import '../avatar_store.dart';
import '../child_soft_ui.dart';

/// Результат модалки «Ваше имя» + фото.
class ParentAccountEditResult {
  ParentAccountEditResult({
    required this.displayName,
    this.newPhoto,
  });

  final String displayName;
  final XFile? newPhoto;
}

const Color _photoFabBlue = Color(0xFF2B88FF);
const double _photoSize = 88;

/// Модалка: смена фото родителя (галерея/камера) и имени без эмодзи в тексте.
Future<ParentAccountEditResult?> showParentAccountEditDialog({
  required BuildContext context,
  required String userId,
  required String displayNameRaw,
  String? avatarImageUrl,
  String? avatarObjectKey,
}) {
  return showDialog<ParentAccountEditResult>(
    context: context,
    builder: (ctx) => _ParentAccountEditDialog(
      userId: userId,
      displayNameRaw: displayNameRaw,
      avatarImageUrl: avatarImageUrl,
      avatarObjectKey: avatarObjectKey,
    ),
  );
}

class _ParentAccountEditDialog extends StatefulWidget {
  const _ParentAccountEditDialog({
    required this.userId,
    required this.displayNameRaw,
    this.avatarImageUrl,
    this.avatarObjectKey,
  });

  final String userId;
  final String displayNameRaw;
  final String? avatarImageUrl;
  final String? avatarObjectKey;

  @override
  State<_ParentAccountEditDialog> createState() =>
      _ParentAccountEditDialogState();
}

class _ParentAccountEditDialogState extends State<_ParentAccountEditDialog> {
  late final TextEditingController _name;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedPhoto;
  Uint8List? _previewBytes;
  int _avatarBump = 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ProfileDisplayName.initial(widget.displayNameRaw),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _fallbackLetter {
    final n = ProfileDisplayName.sanitize(_name.text);
    if (n.isEmpty) return '?';
    return String.fromCharCode(n.runes.first).toUpperCase();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      setState(() {
        _pickedPhoto = img;
        _previewBytes = bytes;
        _avatarBump++;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выбрать фото: $e')),
      );
    }
  }

  Future<void> _showPhotoSources() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: kChildSurfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(sheetCtx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(sheetCtx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await _pickPhoto(
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Widget _avatarCircle() {
    if (_previewBytes != null) {
      return Image.memory(
        _previewBytes!,
        width: _photoSize,
        height: _photoSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    final objectKey = (widget.avatarObjectKey ?? '').trim();
    if (objectKey.isNotEmpty || (widget.avatarImageUrl ?? '').isNotEmpty) {
      return UserAvatar(
        key: ValueKey('dlg-$_avatarBump-$objectKey'),
        userKey: parentProfileAvatarUserKey(widget.userId),
        size: _photoSize,
        fallbackText: _fallbackLetter,
        remoteImageUrl: widget.avatarImageUrl,
        remoteDiskCacheKey: objectKey.isEmpty
            ? null
            : storageObjectDiskCacheKey('member-avatars', objectKey),
      );
    }

    return Container(
      color: _photoFabBlue,
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_camera_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Ваше имя',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: kChildInk,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showPhotoSources,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: _photoSize,
                      height: _photoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarCircle(),
                    ),
                    if (_previewBytes != null || _hasRemoteOrLocalAvatar())
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: _photoFabBlue,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showPhotoSources,
                style: TextButton.styleFrom(foregroundColor: kChildBrandBlue),
                child: Text(
                  _pickedPhoto != null || _hasRemoteOrLocalAvatar()
                      ? 'Изменить фото'
                      : 'Выбрать фото',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Так будет отображаться в семье',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: kChildInkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kChildInk,
              ),
              decoration: InputDecoration(
                hintText: 'Например, Мария',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: kChildBrandBlue, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide:
                      const BorderSide(color: kChildBrandBlue, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FigmaDialogActionStack(
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                final t = ProfileDisplayName.sanitize(_name.text);
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите имя')),
                  );
                  return;
                }
                if (t.length > 120) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Не длиннее 120 символов'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  ParentAccountEditResult(
                    displayName: t,
                    newPhoto: _pickedPhoto,
                  ),
                );
              },
              confirmLabel: 'Сохранить',
            ),
          ],
        ),
      ),
    );
  }

  bool _hasRemoteOrLocalAvatar() {
    if ((widget.avatarImageUrl ?? '').isNotEmpty) return true;
    if ((widget.avatarObjectKey ?? '').trim().isNotEmpty) return true;
    return false;
  }
}
