import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/zemule_admin_app.dart';
import 'config/admin_access.dart';
import 'firebase_options.dart';
import 'screens/not_found_screen.dart';
import 'state/admin_navigation_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (_isSecretAdminPath(Uri.base.path)) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminNavigationState>(
            create: (_) => AdminNavigationState(),
          ),
        ],
        child: const ZemuleAdminApp(),
      ),
    );
    return;
  }

  runApp(const NotFoundApp());
}

bool _isSecretAdminPath(String path) {
  final normalizedPath = _normalizePath(path);
  final normalizedSecret = _normalizePath(kAdminSecretPath);
  return normalizedPath == normalizedSecret;
}

String _normalizePath(String input) {
  String normalized = input.trim();
  if (normalized.isEmpty) {
    normalized = '/';
  }
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

