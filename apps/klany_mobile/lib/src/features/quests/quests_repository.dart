import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/sdk.dart';
import '../auth/child_session.dart';
import '../auth/parent_session.dart';

final questsRepositoryProvider = Provider<QuestsRepository>(
  (ref) => QuestsRepository(ref),
);

class ParentQuestItem {
  ParentQuestItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.questType,
    required this.rewardAmount,
    required this.createdAt,
    required this.distributionType,
    required this.autoApprove,
    required this.timeLimitMinutes,
    required this.scheduleType,
    required this.scheduleDays,
    required this.childIds,
    this.dueAt,
    this.assigneeSince,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String questType;
  final int rewardAmount;
  final DateTime createdAt;
  final String distributionType;
  final bool autoApprove;
  final int? timeLimitMinutes;
  final String scheduleType;
  final List<String> scheduleDays;
  final List<String> childIds;
  final DateTime? dueAt;
  final DateTime? assigneeSince;
}

class ChildQuestAssignmentItem {
  ChildQuestAssignmentItem({
    required this.questId,
    required this.assignmentId,
    required this.title,
    required this.status,
    required this.rewardAmount,
    required this.distributionType,
    required this.autoApprove,
    required this.timeLimitMinutes,
    required this.scheduleType,
    required this.scheduleDays,
    required this.createdAt,
    this.comment,
    this.dueAt,
  });

  final String questId;
  final String assignmentId;
  final String title;
  final String status;
  final int rewardAmount;
  final String distributionType;
  final bool autoApprove;
  final int? timeLimitMinutes;
  final String scheduleType;
  final List<String> scheduleDays;
  final DateTime createdAt;
  final String? comment;
  final DateTime? dueAt;
}

class ParentReviewItem {
  ParentReviewItem({
    required this.questId,
    required this.childId,
    required this.childName,
    required this.title,
    required this.submittedAt,
    this.rewardAmount,
    this.evidencePath,
    this.evidenceUrl,
  });

  final String questId;
  final String childId;
  final String childName;
  final String title;
  final DateTime? submittedAt;
  final int? rewardAmount;
  final String? evidencePath;
  final String? evidenceUrl;
}

class FamilyChildLite {
  FamilyChildLite({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

class QuestsRepository {
  static const _uuid = Uuid();

  QuestsRepository(this.ref);
  final Ref ref;

  String? get _parentToken =>
      ref.read(parentSessionProvider).asData?.value?.accessToken;
  String? get _childToken =>
      ref.read(childSessionProvider).asData?.value?.accessToken;

  Future<String?> _presignDownloadUrl({
    required String token,
    required String bucket,
    required String objectKey,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null || objectKey.trim().isEmpty) return null;
    try {
      final res = await api.postJson(
        '/storage/presign-download',
        accessToken: token,
        body: <String, dynamic>{
          'bucket': bucket,
          'objectKey': objectKey,
          'expiresSeconds': 3600,
        },
      );
      final url = res['url']?.toString();
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<List<FamilyChildLite>> getFamilyChildren(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/family/children', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows
        .map(
          (row) => FamilyChildLite(
            id: row['id'].toString(),
            displayName: (row['displayName'] ?? '').toString(),
          ),
        )
        .toList();
  }

  Future<void> createQuest({
    required String title,
    required String description,
    required int rewardAmount,
    required String questType,
    required DateTime? dueAt,
    required List<String> childIds,
    required String distributionType,
    required bool autoApprove,
    required int? timeLimitMinutes,
    required String scheduleType,
    required List<String> scheduleDays,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) throw Exception('API не настроен');
    await api.postJson(
      '/quests',
      accessToken: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'rewardAmount': rewardAmount,
        'questType': questType,
        'dueAt': dueAt?.toIso8601String(),
        'childIds': childIds,
        'distributionType': distributionType,
        'autoApprove': autoApprove,
        'timeLimitMinutes': timeLimitMinutes,
        'scheduleType': scheduleType,
        'scheduleDays': scheduleDays,
      },
    );
  }

  Future<List<ParentQuestItem>> getParentQuests(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/quests/parent', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows.map((row) {
      return ParentQuestItem(
        id: row['id'].toString(),
        title: (row['title'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        status: (row['status'] ?? '').toString(),
        questType: (row['questType'] ?? '').toString(),
        rewardAmount: (row['reward'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        distributionType: (row['distributionType'] ?? 'assigned').toString(),
        autoApprove: row['autoApprove'] == true,
        timeLimitMinutes: (row['timeLimitMinutes'] as num?)?.toInt(),
        scheduleType: (row['scheduleType'] ?? 'none').toString(),
        scheduleDays:
            (row['scheduleDays'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .toList(),
        childIds: (row['childIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(),
        dueAt: DateTime.tryParse((row['dueAt'] ?? '').toString()),
        assigneeSince: DateTime.tryParse(
          (row['assigneeSince'] ?? '').toString(),
        ),
      );
    }).toList();
  }

  Future<void> updateQuest({
    required String questId,
    required String title,
    required String description,
    required int rewardAmount,
    required String questType,
    required String status,
    required List<String> childIds,
    required String distributionType,
    required bool autoApprove,
    required int? timeLimitMinutes,
    required String scheduleType,
    required List<String> scheduleDays,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.patchJson(
      '/quests/$questId',
      accessToken: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'rewardAmount': rewardAmount,
        'questType': questType.trim(),
        'status': status.trim(),
        'childIds': childIds,
        'distributionType': distributionType,
        'autoApprove': autoApprove,
        'timeLimitMinutes': timeLimitMinutes,
        'scheduleType': scheduleType,
        'scheduleDays': scheduleDays,
      },
    );
  }

  Future<void> closeQuest({required String questId}) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.patchJson(
      '/quests/$questId',
      accessToken: token,
      body: <String, dynamic>{'status': 'closed'},
    );
  }

  Future<void> deleteQuest(String questId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.deleteJson('/quests/$questId', accessToken: token);
  }

  Future<List<ChildQuestAssignmentItem>> getChildAssignments(
    String childId,
  ) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/quests/child', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows.map((row) {
      return ChildQuestAssignmentItem(
        questId: row['questId'].toString(),
        assignmentId: row['assignmentId'].toString(),
        title: (row['title'] ?? '').toString(),
        status: (row['status'] ?? '').toString(),
        rewardAmount: (row['rewardAmount'] as num?)?.toInt() ?? 0,
        distributionType: (row['distributionType'] ?? 'assigned').toString(),
        autoApprove: row['autoApprove'] == true,
        timeLimitMinutes: (row['timeLimitMinutes'] as num?)?.toInt(),
        scheduleType: (row['scheduleType'] ?? 'none').toString(),
        scheduleDays:
            (row['scheduleDays'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .toList(),
        createdAt:
            DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        comment: row['comment']?.toString(),
        dueAt: DateTime.tryParse((row['dueAt'] ?? '').toString()),
      );
    }).toList();
  }

  Future<void> takeFromMarket(String questId) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/quests/child/take',
      accessToken: token,
      body: <String, dynamic>{'questId': questId},
    );
  }

  Future<String> createReverseQuest({
    required String title,
    required int rewardAmount,
    String? description,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) {
      throw Exception('Не авторизован');
    }
    final data = await api.postJson(
      '/quests/child/reverse',
      accessToken: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'rewardAmount': rewardAmount,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return (data['questId'] ?? '').toString();
  }

  Future<Map<String, dynamic>?> getChildReverseQuest() async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) return null;
    try {
      final data = await api.getJson('/quests/child/reverse', accessToken: token);
      return data['item'] as Map<String, dynamic>?;
    } on ApiException catch (e) {
      // Старый backend без маршрута или прокси — как «квеста нет».
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> submitQuestWithEvidence({
    required String questId,
    required XFile? evidenceFile,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _childToken;
    if (api == null || token == null) throw Exception('API не настроен');

    String? evidenceKey;
    if (evidenceFile != null) {
      final Uint8List bytes = await evidenceFile.readAsBytes();
      final path = '${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}.jpg';
      final key = 'quests/$questId/$path';
      final presign = await api.postJson(
        '/storage/presign-upload',
        accessToken: token,
        body: <String, dynamic>{'bucket': 'quest-evidence', 'objectKey': key},
      );
      final url = presign['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        final put = await http.put(Uri.parse(url), body: bytes);
        ApiClient.notifyUnauthorizedFromStatusCode(put.statusCode);
        if (put.statusCode < 200 || put.statusCode >= 300) {
          throw Exception('Загрузка файла: ${put.statusCode}');
        }
        evidenceKey = key;
      }
    }

    await api.postJson(
      '/quests/child/submit',
      accessToken: token,
      body: <String, dynamic>{'questId': questId, 'evidenceKey': evidenceKey},
    );
  }

  Future<List<ParentReviewItem>> getSubmittedForReview(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/quests/review', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return Future.wait(
      rows.map((row) async {
        final evidencePath = row['evidenceKey']?.toString();
        final evidenceUrl = (evidencePath != null && evidencePath.isNotEmpty)
            ? await _presignDownloadUrl(
                token: token,
                bucket: 'quest-evidence',
                objectKey: evidencePath,
              )
            : null;
        return ParentReviewItem(
          questId: row['questId'].toString(),
          childId: row['childId'].toString(),
          childName: (row['childName'] ?? '').toString(),
          title: (row['title'] ?? '').toString(),
          submittedAt: DateTime.tryParse((row['submittedAt'] ?? '').toString()),
          rewardAmount:
              (row['rewardAmount'] as num?)?.toInt() ??
                  (row['reward'] as num?)?.toInt(),
          evidencePath: evidencePath,
          evidenceUrl: evidenceUrl,
        );
      }),
    );
  }

  Future<void> reviewSubmission({
    required String questId,
    required String childId,
    required bool approve,
    required String comment,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _parentToken;
    if (api == null || token == null) return;
    await api.postJson(
      '/quests/review',
      accessToken: token,
      body: <String, dynamic>{
        'questId': questId,
        'childId': childId,
        'approve': approve,
        'comment': comment.trim().isEmpty ? null : comment.trim(),
      },
    );
  }
}
