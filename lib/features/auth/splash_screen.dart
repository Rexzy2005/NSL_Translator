import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/hive_service.dart';
import '../../shared/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _logo = 'NSL';
  static const String _subtitle = 'Translate';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _routeAfterDelay();
  }

  Future<void> _routeAfterDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    final auth = AuthService();
    final hasAccess = auth.getCurrentUser() != null || auth.isGuest;
    final hive = context.read<HiveService>();
    final onboardingDone =
        hive.getStringSetting('onboarding_done', defaultValue: 'false') ==
            'true';
    final permissionsDone =
        hive.getStringSetting('permissions_done', defaultValue: 'false') ==
            'true';
    if (hasAccess) {
      context.go(permissionsDone ? '/home' : '/permissions');
    } else {
      context.go(onboardingDone ? '/welcome' : '/onboarding');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSlide(
                  offset: _started ? const Offset(-0.68, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  child: const Text(
                    _logo,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                AnimatedSlide(
                  offset: _started
                      ? const Offset(0.78, 0.12)
                      : const Offset(1.5, 0.12),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _started ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: const Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
