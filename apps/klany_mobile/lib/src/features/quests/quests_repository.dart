import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
    required this.status,
    required this.questType,
    required this.rewardAmount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String questType;
  final int rewardAmount;
  final DateTime createdAt;
}

class ChildQuestAssignmentItem {
  ChildQuestAssignmentItem({
    required this.questId,
    required this.assignmentId,
    required this.title,
    required this.status,
    required this.rewardAmount,
    this.comment,
    this.dueAt,
  });

  final String questId;
  final String assignmentId;
  final String title;
  final String status;
  final int rewardAmount;
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
    this.evidencePath,
  });

  final String questId;
  final String childId;
  final String childName;
  final String title;
  final DateTime? submittedAt;
  final String? evidencePath;
}

class FamilyChildLite {
  FamilyChildLite({
    required this.id,
    required this.displayName,
  });

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
        status: (row['status'] ?? '').toString(),
        questType: (row['questType'] ?? '').toString(),
        rewardAmount: (row['reward'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<List<ChildQuestAssignmentItem>> getChildAssignments(String childId) async {
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
        comment: row['comment']?.toString(),
        dueAt: DateTime.tryParse((row['dueAt'] ?? '').toString()),
      );
    }).toList();
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
        await http.put(Uri.parse(url),
            headers: <String, String>{'Content-Type': 'image/jpeg'}, body: bytes);
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
    return rows.map((row) {
      return ParentReviewItem(
        questId: row['questId'].toString(),
        childId: row['childId'].toString(),
        childName: (row['childName'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        submittedAt: DateTime.tryParse((row['submittedAt'] ?? '').toString()),
        evidencePath: row['evidenceKey']?.toString(),
      );
    }).toList();
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

