import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_role.dart';
import 'child_session.dart';
import 'parent_session.dart';

final appRoleProvider = Provider<AppRole?>((ref) {
  final parent = ref.watch(parentSessionProvider).asData?.value;
  if (parent != null) return AppRole.parent;
  final child = ref.watch(childSessionProvider).asData?.value;
  if (child != null) return AppRole.child;
  return null;
});

