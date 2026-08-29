import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_presign.dart';
import '../auth/parent_session.dart';
import 'avatar_store.dart';

/// Аватар из MinIO (`member-avatars`): один стабильный [Future] на пару token+objectKey,
/// первый кадр берёт URL из памятного кэша presign ([peekPresignedStorageDownloadUrl]).
class PresignedMemberAvatar extends StatefulWidget {
  const PresignedMemberAvatar({
    super.key,
    required this.accessToken,
    required this.objectKey,
    required this.userKey,
    required this.size,
    this.fallbackText,
    this.bucket = 'member-avatars',
  });

  final String accessToken;
  final String objectKey;
  final String userKey;
  final double size;
  final String? fallbackText;
  final String bucket;

  @override
  State<PresignedMemberAvatar> createState() => _PresignedMemberAvatarState();
}

class _PresignedMemberAvatarState extends State<PresignedMemberAvatar> {
  Future<String?>? _presignFuture;
  String? _lastObjectKey;
  String? _lastToken;

  void _ensureFuture() {
    final changed = _lastObjectKey != widget.objectKey ||
        _lastToken != widget.accessToken;
    if (!changed && _presignFuture != null) return;
    _lastObjectKey = widget.objectKey;
    _lastToken = widget.accessToken;
    _presignFuture = presignStorageDownload(
      accessToken: widget.accessToken,
      bucket: widget.bucket,
      objectKey: widget.objectKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureFuture();
    final initial = peekPresignedStorageDownloadUrl(
      bucket: widget.bucket,
      objectKey: widget.objectKey,
    );
    return FutureBuilder<String?>(
      future: _presignFuture,
      initialData: initial,
      builder: (context, snap) {
        return UserAvatar(
          userKey: widget.userKey,
          size: widget.size,
          fallbackText: widget.fallbackText,
          remoteImageUrl: snap.data,
          remoteDiskCacheKey:
              storageObjectDiskCacheKey(widget.bucket, widget.objectKey),
        );
      },
    );
  }
}

/// Аватар участника семьи: presigned URL, lazy presign по [avatarObjectKey] или локальный fallback.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    super.key,
    required this.userKey,
    required this.size,
    this.fallbackText,
    this.avatarObjectKey,
    this.avatarImageUrl,
    this.accessToken,
    this.bucket = 'member-avatars',
  });

  final String userKey;
  final double size;
  final String? fallbackText;
  final String? avatarObjectKey;
  final String? avatarImageUrl;
  final String? accessToken;
  final String bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = (avatarImageUrl ?? '').trim();
    final objectKey = (avatarObjectKey ?? '').trim();
    if (url.isNotEmpty) {
      return UserAvatar(
        userKey: userKey,
        size: size,
        fallbackText: fallbackText,
        remoteImageUrl: url,
        remoteDiskCacheKey: objectKey.isEmpty
            ? null
            : storageObjectDiskCacheKey(bucket, objectKey),
      );
    }
    if (objectKey.isNotEmpty) {
      final token = (accessToken ?? '').trim().isNotEmpty
          ? accessToken!.trim()
          : ref.read(parentSessionProvider).asData?.value?.accessToken;
      if (token != null && token.isNotEmpty) {
        return PresignedMemberAvatar(
          accessToken: token,
          objectKey: objectKey,
          userKey: userKey,
          size: size,
          fallbackText: fallbackText,
          bucket: bucket,
        );
      }
    }
    return UserAvatar(
      userKey: userKey,
      size: size,
      fallbackText: fallbackText,
    );
  }
}
