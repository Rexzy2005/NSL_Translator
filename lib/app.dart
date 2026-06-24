import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/permission_gate_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/main_scaffold.dart';

class NSLTranslateApp extends StatefulWidget {
  const NSLTranslateApp({super.key});

  @override
  State<NSLTranslateApp> createState() => _NSLTranslateAppState();
}

class _NSLTranslateAppState extends State<NSLTranslateApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) =>
            _fadePage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) =>
            _fadePage(state, const PermissionGateScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _fadePage(state, const MainScaffold()),
      ),
    ],
    redirect: (context, state) {
      final auth = AuthService();
      final location = state.matchedLocation;
      final allowed = auth.getCurrentUser() != null || auth.isGuest;
      if (!allowed && (location == '/home' || location == '/permissions')) {
        return '/welcome';
      }
      return null;
    },
  );

  CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
