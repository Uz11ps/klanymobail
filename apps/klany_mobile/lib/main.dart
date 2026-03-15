import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Runtime config (url/key) lives in `.env` and is loaded as an asset.
  await dotenv.load(fileName: '.env');
  Env.validate();

  // Run app immediately; Firebase init goes in background and must not block first frame.
  unawaited(_initFirebaseSafe());

  // If API base url is empty, app still boots in "demo mode" (no network calls).

  runApp(const ProviderScope(child: App()));
}

Future<void> _initFirebaseSafe() async {
  // Firebase is only required for push notifications (FCM).
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}
