import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/sdk.dart';

final questsRepositoryProvider = Provider<QuestsRepository>(
  (ref) => QuestsRepository(),
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
  static const _bucket = 'quest-evidence';
  static const _uuid = Uuid();

  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<List<FamilyChildLite>> getFamilyChildren(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('children')
        .select('id, display_name')
        .eq('family_id', familyId)
        .eq('is_active', true)
        .order('display_name');

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => FamilyChildLite(
            id: row['id'].toString(),
            displayName: (row['display_name'] ?? '').toString(),
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
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');
    await client.rpc(
      'parent_create_quest',
      params: <String, dynamic>{
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_reward_amount': rewardAmount,
        'p_quest_type': questType,
        'p_due_at': dueAt?.toIso8601String(),
        'p_child_ids': childIds,
      },
    );
  }

  Future<List<ParentQuestItem>> getParentQuests(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('quests')
        .select('id, title, status, quest_type, reward_amount, created_at')
        .eq('family_id', familyId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => ParentQuestItem(
            id: row['id'].toString(),
            title: (row['title'] ?? '').toString(),
            status: (row['status'] ?? '').toString(),
            questType: (row['quest_type'] ?? '').toString(),
            rewardAmount: (row['reward_amount'] as num?)?.toInt() ?? 0,
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                    DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<ChildQuestAssignmentItem>> getChildAssignments(String childId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('quest_assignees')
        .select('id, quest_id, status, reward_amount, comment, quests(title, due_at)')
        .eq('child_id', childId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map((row) {
      final quest = (row['quests'] as Map<String, dynamic>? ?? <String, dynamic>{});
      return ChildQuestAssignmentItem(
        questId: row['quest_id'].toString(),
        assignmentId: row['id'].toString(),
        title: (quest['title'] ?? '').toString(),
        status: (row['status'] ?? '').toString(),
        rewardAmount: (row['reward_amount'] as num?)?.toInt() ?? 0,
        comment: row['comment']?.toString(),
        dueAt: DateTime.tryParse((quest['due_at'] ?? '').toString()),
      );
    }).toList();
  }

  Future<void> submitQuestWithEvidence({
    required String questId,
    required XFile? evidenceFile,
  }) async {
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');

    if (evidenceFile != null) {
      final Uint8List bytes = await evidenceFile.readAsBytes();
      final path = '${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}.jpg';
      final fullPath = 'quests/$questId/$path';
      await client.storage.from(_bucket).uploadBinary(
            fullPath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );
      await client.from('quest_evidence').insert(<String, dynamic>{
        'quest_id': questId,
        'storage_path': fullPath,
      });
    }

    await client.rpc(
      'child_submit_quest',
      params: <String, dynamic>{'p_quest_id': questId},
    );
  }

  Future<List<ParentReviewItem>> getSubmittedForReview(String familyId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('quest_assignees')
        .select(
            'quest_id, child_id, submitted_at, quests(title, family_id), children(display_name)')
        .eq('status', 'submitted')
        .order('submitted_at', ascending: false);

    final base = (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .where((row) {
      final quest = row['quests'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return quest['family_id']?.toString() == familyId;
    }).toList();

    final result = <ParentReviewItem>[];
    for (final row in base) {
      final questId = row['quest_id'].toString();
      final evRows = await client
          .from('quest_evidence')
          .select('storage_path')
          .eq('quest_id', questId)
          .order('created_at', ascending: false)
          .limit(1);
      final evList = evRows as List<dynamic>;
      final evidencePath = evList.isNotEmpty
          ? (evList.first['storage_path'])?.toString()
          : null;

      final quest = row['quests'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final child = row['children'] as Map<String, dynamic>? ?? <String, dynamic>{};
      result.add(
        ParentReviewItem(
          questId: questId,
          childId: row['child_id'].toString(),
          childName: (child['display_name'] ?? '').toString(),
          title: (quest['title'] ?? '').toString(),
          submittedAt:
              DateTime.tryParse((row['submitted_at'] ?? '').toString()),
          evidencePath: evidencePath,
        ),
      );
    }
    return result;
  }

  Future<void> reviewSubmission({
    required String questId,
    required String childId,
    required bool approve,
    required String comment,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_review_quest_submission',
      params: <String, dynamic>{
        'p_quest_id': questId,
        'p_child_id': childId,
        'p_approve': approve,
        'p_comment': comment.trim().isEmpty ? null : comment.trim(),
      },
    );
  }
}

