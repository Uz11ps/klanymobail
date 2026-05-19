import 'package:flutter/material.dart';

import '../../core/storage_presign.dart';
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
        );
      },
    );
  }
}
