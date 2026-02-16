import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';
import 'app_role.dart';

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = Sdk.supabaseOrNull;
  if (client == null) {
    yield null;
    return;
  }

  yield client.auth.currentSession;

  await for (final state in client.auth.onAuthStateChange) {
    yield state.session;
  }
});

final appRoleProvider = Provider<AppRole?>((ref) {
  final session = ref.watch(authSessionProvider).asData?.value;
  final raw = session?.user.userMetadata?['app_role']?.toString();
  return AppRoleX.fromKey(raw);
});

