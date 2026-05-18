import 'sdk.dart';

/// Краткоживущая ссылка на объект в MinIO (чтение).
Future<String?> presignStorageDownload({
  required String accessToken,
  required String bucket,
  required String objectKey,
  int expiresSeconds = 3600,
}) async {
  final api = Sdk.apiOrNull;
  if (api == null || objectKey.trim().isEmpty) return null;
  try {
    final res = await api.postJson(
      '/storage/presign-download',
      accessToken: accessToken,
      body: <String, dynamic>{
        'bucket': bucket,
        'objectKey': objectKey,
        'expiresSeconds': expiresSeconds,
      },
    );
    final url = res['url']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  } catch (_) {
    return null;
  }
}
