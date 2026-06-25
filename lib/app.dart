import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
        pageBuilder: (context, state) =>
            _fadePage(state, const SplashScreen(), 360),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) =>
            _fadePage(state, const WelcomeScreen(), 320),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen(), 320),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) =>
            _slideUpPage(state, const PermissionGateScreen()),
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
      // If auth is done but permissions haven't been granted yet,
      // send to permission gate (unless already there)
      if (allowed &&
          location != '/permissions' &&
          location != '/onboarding' &&
          location != '/welcome' &&
          location != '/splash') {
        final settingsBox = Hive.box<dynamic>(AppConstants.hiveSettingsBox);
        final permissionsDone =
            settingsBox.get('permissions_done', defaultValue: 'false') == 'true';
        if (!permissionsDone) {
          return '/permissions';
        }
      }
      return null;
    },
  );

  CustomTransitionPage<void> _fadePage(
    GoRouterState state,
    Widget child, [
    int durationMs = 280,
  ]) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Duration(milliseconds: durationMs),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }

  CustomTransitionPage<void> _slideUpPage(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
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