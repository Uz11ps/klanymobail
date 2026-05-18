import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/sdk.dart';
import 'child_session.dart';

const _uuid = Uuid();

Future<void> uploadChildAvatarXFile(WidgetRef ref, XFile imageFile) async {
  final session = ref.read(childSessionProvider).asData?.value;
  final api = Sdk.apiOrNull;
  if (session == null || api == null) {
    throw Exception('Нет сессии ребёнка');
  }

  final bytes = await imageFile.readAsBytes();
  var ext = imageFile.path.split('.').last.toLowerCase();
  if (ext.length > 5) ext = 'jpg';
  final key =
      'avatars/families/${session.familyId}/children/${session.childId}/${_uuid.v4()}.$ext';

  final presign = await api.postJson(
    '/storage/presign-upload',
    accessToken: session.accessToken,
    body: <String, dynamic>{
      'bucket': 'member-avatars',
      'objectKey': key,
    },
  );
  final url = presign['url']?.toString() ?? '';
  if (url.isEmpty) throw Exception('Не удалось получить ссылку загрузки');

  final put = await http.put(Uri.parse(url), body: bytes);
  if (put.statusCode < 200 || put.statusCode >= 300) {
    throw Exception('Загрузка файла: ${put.statusCode}');
  }

  await api.patchJson(
    '/child/me/avatar',
    accessToken: session.accessToken,
    body: <String, dynamic>{'objectKey': key},
  );
  await ref.read(childSessionProvider.notifier).setAvatarObjectKey(key);
}

Future<void> uploadChildAvatarPngBytes(WidgetRef ref, Uint8List pngBytes) async {
  final session = ref.read(childSessionProvider).asData?.value;
  final api = Sdk.apiOrNull;
  if (session == null || api == null) {
    throw Exception('Нет сессии ребёнка');
  }

  final key =
      'avatars/families/${session.familyId}/children/${session.childId}/${_uuid.v4()}.png';

  final presign = await api.postJson(
    '/storage/presign-upload',
    accessToken: session.accessToken,
    body: <String, dynamic>{
      'bucket': 'member-avatars',
      'objectKey': key,
    },
  );
  final url = presign['url']?.toString() ?? '';
  if (url.isEmpty) throw Exception('Не удалось получить ссылку загрузки');

  final put = await http.put(Uri.parse(url), body: pngBytes);
  if (put.statusCode < 200 || put.statusCode >= 300) {
    throw Exception('Загрузка файла: ${put.statusCode}');
  }

  await api.patchJson(
    '/child/me/avatar',
    accessToken: session.accessToken,
    body: <String, dynamic>{'objectKey': key},
  );
  await ref.read(childSessionProvider.notifier).setAvatarObjectKey(key);
}
