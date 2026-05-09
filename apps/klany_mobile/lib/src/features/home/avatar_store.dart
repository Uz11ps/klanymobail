import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'child_soft_ui.dart';

/// Глобальный notifier — все UserAvatar пере-загружаются когда что-то меняется.
final ValueNotifier<int> avatarVersion = ValueNotifier<int>(0);

/// Локальное хранилище выбранного аватара по идентификатору пользователя.
/// Может хранить либо индекс предустановленного (1..9), либо путь к загруженному файлу.
class AvatarStore {
  static const _idxPrefix = 'avatar_idx_';
  static const _filePrefix = 'avatar_file_';
  static const totalAvatars = 9;

  /// Возвращает путь к загруженному файлу или null.
  static Future<String?> getFilePath(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_filePrefix$key');
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  /// Возвращает индекс аватара (1..9) если файла нет.
  static Future<int> getIndex(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('$_idxPrefix$key');
    if (saved != null && saved >= 1 && saved <= totalAvatars) return saved;
    return (key.hashCode.abs() % totalAvatars) + 1;
  }

  static int fallbackIndex(String key) =>
      (key.hashCode.abs() % totalAvatars) + 1;

  static Future<void> setIndex(String key, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_idxPrefix$key', index);
    await prefs.remove('$_filePrefix$key');
    avatarVersion.value++;
  }

  static Future<void> setFilePath(String key, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_filePrefix$key', path);
    avatarVersion.value++;
  }

  static String assetForIndex(int index) => 'assets/figma/avatar_$index.png';
}

/// Копирует выбранный файл в постоянное хранилище приложения и сохраняет путь.
Future<String?> _pickAndStoreImage(String userKey) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final ext = picked.path.split('.').last.toLowerCase();
  final dest =
      '${dir.path}/avatar_${userKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_$stamp.$ext';
  await File(picked.path).copy(dest);
  await AvatarStore.setFilePath(userKey, dest);
  return dest;
}

/// Диалог выбора аватара: 9 готовых + кнопка "Загрузить из галереи".
Future<bool> showAvatarPicker({
  required BuildContext context,
  required String userKey,
  String? title,
}) async {
  final initial = await AvatarStore.getIndex(userKey);
  if (!context.mounted) return false;
  int selected = initial;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          title ?? 'Выбрать аватар',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: AvatarStore.totalAvatars,
                itemBuilder: (_, i) {
                  final idx = i + 1;
                  final isSelected = idx == selected;
                  return GestureDetector(
                    onTap: () => setSt(() => selected = idx),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? kChildBrandBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          AvatarStore.assetForIndex(idx),
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Container(
                            color: kBrandMint,
                            alignment: Alignment.center,
                            child: Text('$idx'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = await _pickAndStoreImage(userKey);
                    if (p != null && ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Загрузить из галереи'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kChildBrandBlue,
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(
                      color: kChildBrandBlue,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kBrandMint,
              foregroundColor: const Color(0xFF1F4F1B),
              elevation: 4,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
  if (result == true) {
    // Если выбран один из 9 (а не загружен файл) — сохраняем индекс.
    final hasFile = await AvatarStore.getFilePath(userKey) != null;
    if (!hasFile) {
      await AvatarStore.setIndex(userKey, selected);
    }
    return true;
  }
  return false;
}

/// Виджет круглого аватара. Сначала пробует файл, потом asset.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.userKey,
    required this.size,
    this.fallbackText,
  });
  final String userKey;
  final double size;
  final String? fallbackText;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  late int _index = AvatarStore.fallbackIndex(widget.userKey);
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _load();
    avatarVersion.addListener(_onAvatarChanged);
  }

  @override
  void dispose() {
    avatarVersion.removeListener(_onAvatarChanged);
    super.dispose();
  }

  void _onAvatarChanged() {
    _load();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userKey != widget.userKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final path = await AvatarStore.getFilePath(widget.userKey);
    final idx = await AvatarStore.getIndex(widget.userKey);
    if (!mounted) return;
    if (path != null) {
      // сбросить кеш картинки чтоб обновилась если файл перезаписали
      try {
        FileImage(File(path)).evict();
      } catch (_) {}
    }
    setState(() {
      _filePath = path;
      _index = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF2F8),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _filePath != null
          ? Image.file(
              File(_filePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _assetImage(),
            )
          : _assetImage(),
    );
  }

  Widget _assetImage() => Image.asset(
        AvatarStore.assetForIndex(_index),
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => Text(
          widget.fallbackText ?? '?',
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.w900,
            color: kChildBrandBlue,
          ),
        ),
      );
}
