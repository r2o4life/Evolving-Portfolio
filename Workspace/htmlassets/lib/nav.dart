import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:html_artifact_pipeline/pages/compiler_page.dart';
import 'package:html_artifact_pipeline/pages/ingress_page.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const IngressPage(),
        ),
      ),

      GoRoute(
        path: AppRoutes.compiler,
        name: 'compiler',
        pageBuilder: (context, state) {
          final initialPrompt = state.extra is String ? state.extra as String : null;
          return NoTransitionPage(child: CompilerPage(initialPrompt: initialPrompt));
        },
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String home = '/';
  static const String compiler = '/compiler';
}
