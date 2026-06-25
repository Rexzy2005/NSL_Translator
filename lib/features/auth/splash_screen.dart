import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/hive_service.dart';
import '../../shared/widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _tagline = 'Bridging the communication gap';
  bool _started = false;

  late final AnimationController _gradientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

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
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFFE8F8F1),
                    const Color(0xFFD9F1F9),
                    _gradientController.value,
                  )!,
                  const Color(0xFFF8F9FA),
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandLogo(revealed: _started),
                AnimatedOpacity(
                  opacity: _started ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _tagline,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
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