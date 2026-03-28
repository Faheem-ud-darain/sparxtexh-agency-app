import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Replace with actual FirebaseOptions generated via 'flutterfire configure'
  // Or run it now if you have the CLI installed.
  // For now, initializing with default/dummy if not configured.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Initialization failed: $e');
    // Consider adding a graceful failure/retry for development
  }

  runApp(
    const ProviderScope(
      child: CompanyApp(),
    ),
  );
}
