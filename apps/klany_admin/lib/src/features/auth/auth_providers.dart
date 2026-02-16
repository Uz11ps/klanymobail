import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';

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

