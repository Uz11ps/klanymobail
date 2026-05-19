import 'api_client.dart';
import 'sdk.dart';

class _CachedPresign {
  _CachedPresign(this.url, this.validUntil);
  final String url;
  final DateTime validUntil;
}

/// Кэш presigned GET URL по `(bucket, objectKey)` + объединение параллельных запросов.
///
/// Новый URL при каждом вызове API ломает [Image.network] disk/memory cache Flutter —
/// здесь переиспользуем строку URL до истечения TTL.
final class PresignStorageDownloadCache {
  PresignStorageDownloadCache._();

  static final Map<String, _CachedPresign> _entries = {};
  static final Map<String, Future<String?>> _inFlight = {};

  static String _cacheKey(String bucket, String objectKey) =>
      '${bucket.trim()}\x00${objectKey.trim()}';

  /// Готовый URL из кэша, если он ещё действителен (с запасом [skew] до истечения).
  static String? peekFresh({
    required String bucket,
    required String objectKey,
    Duration skew = const Duration(seconds: 120),
  }) {
    final ck = _cacheKey(bucket, objectKey);
    final e = _entries[ck];
    if (e == null) return null;
    final deadline = e.validUntil.subtract(skew);
    if (!DateTime.now().isBefore(deadline)) {
      _entries.remove(ck);
      return null;
    }
    return e.url;
  }

  static void invalidate({required String bucket, required String objectKey}) {
    _entries.remove(_cacheKey(bucket, objectKey));
  }

  static void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  static Future<String?> resolve({
    required String accessToken,
    required String bucket,
    required String objectKey,
    int expiresSeconds = 3600,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null || objectKey.trim().isEmpty) return null;

    final ck = _cacheKey(bucket, objectKey);

    final cached = peekFresh(bucket: bucket, objectKey: objectKey);
    if (cached != null) return cached;

    final pending = _inFlight[ck];
    if (pending != null) return pending;

    final fut = _fetchPresign(
      api,
      accessToken: accessToken,
      bucket: bucket,
      objectKey: objectKey,
      expiresSeconds: expiresSeconds,
    ).then((url) {
      _inFlight.remove(ck);
      if (url != null && url.isNotEmpty) {
        final ttlSeconds = (expiresSeconds - 120).clamp(120, expiresSeconds);
        _entries[ck] = _CachedPresign(
          url,
          DateTime.now().add(Duration(seconds: ttlSeconds)),
        );
      }
      return url;
    }).catchError((_) {
      _inFlight.remove(ck);
      return null;
    });

    _inFlight[ck] = fut;
    return fut;
  }
}

Future<String?> _fetchPresign(
  ApiClient api, {
  required String accessToken,
  required String bucket,
  required String objectKey,
  required int expiresSeconds,
}) async {
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

/// Синхронно вернуть актуальный из кэша URL (для [FutureBuilder.initialData]).
String? peekPresignedStorageDownloadUrl({
  required String bucket,
  required String objectKey,
}) =>
    PresignStorageDownloadCache.peekFresh(bucket: bucket, objectKey: objectKey);

Future<String?> presignStorageDownload({
  required String accessToken,
  required String bucket,
  required String objectKey,
  int expiresSeconds = 3600,
}) =>
    PresignStorageDownloadCache.resolve(
      accessToken: accessToken,
      bucket: bucket,
      objectKey: objectKey,
      expiresSeconds: expiresSeconds,
    );

void invalidatePresignStorageDownload({
  required String bucket,
  required String objectKey,
}) =>
    PresignStorageDownloadCache.invalidate(bucket: bucket, objectKey: objectKey);

void clearPresignStorageDownloadCache() => PresignStorageDownloadCache.clear();
