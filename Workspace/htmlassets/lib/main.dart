import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:html_artifact_pipeline/firebase_options.dart';
import 'package:html_artifact_pipeline/nav.dart';
import 'package:html_artifact_pipeline/theme.dart';

/// Main entry point for the application
///
/// This sets up:
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Keep the app usable even if Firebase isn't configured for the current build.
    // Cloud Functions calls will gracefully fall back client-side.
    debugPrint('Firebase init failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // As you extend the app, use MultiProvider to wrap the app
    // and provide state to all widgets
    // Example:
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => ExampleProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Dreamflow Starter',
    //     debugShowCheckedModeBanner: false,
    //     routerConfig: AppRouter.router,
    //   ),
    // );
    return MaterialApp.router(
      title: 'Dreamflow Starter',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,

      // Router configuration
      routerConfig: AppRouter.router,
    );
  }
}
