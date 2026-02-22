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

  // If API base url is empty, app still boots in "demo mode" (no network calls).

  runApp(const ProviderScope(child: App()));
}
